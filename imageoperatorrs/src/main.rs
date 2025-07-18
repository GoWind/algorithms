use anyhow::Result;
use base64::Engine;
use futures::StreamExt;
use kube::runtime::controller::{Action, Controller};
use kube::{
    api::{Api, Patch, PatchParams, ResourceExt},
    client::Client,
    runtime::watcher::Config,
    CustomResource,
};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::sync::Arc;
use std::time::Duration;
use thiserror::Error;
use tracing::{error, info, warn};

#[derive(CustomResource, Deserialize, Serialize, Clone, Debug, Default, JsonSchema)]
#[kube(
    group = "imaging.example.com",
    version = "v1",
    kind = "ImageProcessor",
    plural = "imageprocessors",
    status = "ImageProcessorStatus",
    namespaced
)]
#[kube(printcolumn = r#"{"name":"Operation", "type":"string", "jsonPath":".spec.operation"}"#)]
#[kube(printcolumn = r#"{"name":"Phase", "type":"string", "jsonPath":".status.phase"}"#)]
#[kube(printcolumn = r#"{"name":"Age", "type":"date", "jsonPath":".metadata.creationTimestamp"}"#)]
pub struct ImageProcessorSpec {
    /// Base64 encoded JPEG image data
    #[serde(default)]
    pub data: String,
    /// Image operation to perform
    #[serde(default)]
    pub operation: String,
    /// Parameters for the operation
    #[serde(default)]
    pub params: Option<Value>,
}

#[derive(Deserialize, Serialize, Clone, Default, Debug, JsonSchema)]
pub struct ImageProcessorStatus {
    /// Current processing phase
    #[serde(skip_serializing_if = "Option::is_none")]
    pub phase: Option<String>,
    /// Base64 encoded processed image result
    #[serde(skip_serializing_if = "Option::is_none")]
    pub result: Option<String>,
    /// Status message
    #[serde(skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,
}

#[derive(Error, Debug)]
pub enum ProcessingError {
    #[error("Base64 decode error: {0}")]
    Base64Error(#[from] base64::DecodeError),
    #[error("Image decode error: {0}")]
    ImageError(#[from] image::ImageError),
    #[error("Unknown operation: {0}")]
    UnknownOperation(String),
    #[error("Parameter error: {0}")]
    ParameterError(String),
}

struct Context {
    client: Client,
}

async fn reconcile(processor: Arc<ImageProcessor>, ctx: Arc<Context>) -> Result<Action, kube::Error> {
    let name = processor.name_any();
    let ns = processor.namespace().unwrap_or_default();
    
    info!("Reconciling ImageProcessor {}/{}", ns, name);

    let api: Api<ImageProcessor> = Api::namespaced(ctx.client.clone(), &ns);

    // Get current status
    let current_phase = processor.status.as_ref()
        .and_then(|s| s.phase.as_ref())
        .map(String::as_str)
        .unwrap_or("");

    // Skip if already processed
    if current_phase == "Complete" || current_phase == "Failed" {
        return Ok(Action::await_change());
    }

    // Update status to Processing
    let mut updated = (*processor).clone();
    updated.status = Some(ImageProcessorStatus {
        phase: Some("Processing".to_string()),
        message: Some("Processing image...".to_string()),
        result: None,
    });

    let patch = Patch::Merge(serde_json::json!({
        "status": updated.status
    }));
    api.patch_status(&name, &PatchParams::default(), &patch).await?;

    // Process the image
    match process_image(&processor.spec).await {
        Ok(result) => {
            // Update with success
            let status = ImageProcessorStatus {
                phase: Some("Complete".to_string()),
                message: Some("Image processed successfully".to_string()),
                result: Some(result),
            };
            let patch = Patch::Merge(serde_json::json!({"status": status}));
            api.patch_status(&name, &PatchParams::default(), &patch).await?;
            info!("Successfully processed {}/{}", ns, name);
        }
        Err(e) => {
            // Update with failure
            let status = ImageProcessorStatus {
                phase: Some("Failed".to_string()),
                message: Some(format!("Processing failed: {}", e)),
                result: None,
            };
            let patch = Patch::Merge(serde_json::json!({"status": status}));
            api.patch_status(&name, &PatchParams::default(), &patch).await?;
            error!("Failed to process {}/{}: {}", ns, name, e);
        }
    }

    Ok(Action::await_change())
}

async fn process_image(spec: &ImageProcessorSpec) -> Result<String, ProcessingError> {
    // Decode base64 image
    let img_data = base64::engine::general_purpose::STANDARD.decode(&spec.data)?;
    
    // Load image
    let img = image::load_from_memory(&img_data)?;
    
    // Apply operation
    let processed = match spec.operation.as_str() {
        "flip" => {
            let direction = spec.params.as_ref()
                .and_then(|p| p.get("direction"))
                .and_then(|d| d.as_str())
                .unwrap_or("horizontal");
            
            match direction {
                "vertical" => img.flipv(),
                _ => img.fliph(),
            }
        }
        "rotate" => {
            let angle = spec.params.as_ref()
                .and_then(|p| p.get("angle"))
                .and_then(|a| a.as_f64())
                .unwrap_or(90.0);
            
            match angle as i32 {
                90 => img.rotate90(),
                180 => img.rotate180(),
                270 => img.rotate270(),
                _ => return Err(ProcessingError::ParameterError(
                    "Only 90, 180, 270 degree rotations supported".to_string()
                )),
            }
        }
        "resize" => {
            let width = spec.params.as_ref()
                .and_then(|p| p.get("width"))
                .and_then(|w| w.as_u64())
                .unwrap_or(100) as u32;
            
            let height = spec.params.as_ref()
                .and_then(|p| p.get("height"))
                .and_then(|h| h.as_u64())
                .unwrap_or(100) as u32;
            
            img.resize(width, height, image::imageops::FilterType::Lanczos3)
        }
        op => return Err(ProcessingError::UnknownOperation(op.to_string())),
    };

    // Encode back to JPEG
    let mut output = Vec::new();
    processed.write_to(&mut std::io::Cursor::new(&mut output), image::ImageOutputFormat::Jpeg(85))?;
    
    // Encode to base64
    Ok(base64::engine::general_purpose::STANDARD.encode(output))
}

fn error_policy(_processor: Arc<ImageProcessor>, error: &kube::Error, _ctx: Arc<Context>) -> Action {
    warn!("Reconcile failed: {:?}", error);
    Action::requeue(Duration::from_secs(60))
}

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt::init();

    let client = Client::try_default().await?;
    let api = Api::<ImageProcessor>::all(client.clone());
    let context = Arc::new(Context { client: client.clone() });

    info!("Starting Image Processor Operator");

    Controller::new(api, Config::default())
        .run(reconcile, error_policy, context)
        .for_each(|res| async move {
            match res {
                Ok(_) => {},
                Err(e) => error!("Controller error: {:?}", e),
            }
        })
        .await;

    Ok(())
}
