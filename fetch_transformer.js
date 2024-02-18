"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    

    function adopt(value) { 
        return value instanceof P ? value : new P(function (resolve) { resolve(value); }); 
    }
    return new (P || (P = Promise))(function (resolve, reject) {
        const genInstance = generator.apply(thisArg, _arguments || []);
        const fulfilled = (value) => { try { 
                      step(genInstance.next(value)); 
                    } catch (e) { reject(e); }
        } 
        const rejected = (value) => { try { step(genInstance["throw"](value)); } catch (e) { reject(e); } }

        function step(result) { 
            if(result.done) { 
              resolve(result.value) 
            } else {
              adopt(result.value).then(fulfilled, rejected); 
            }
        }
        // const generated_value = generator.apply(thisArg, _arguments || []).next();
        step(genInstance.next());
    });
};

function getTextOrBust() {
    return __awaiter(this, void 0, void 0, function* () {
        const resp = yield fetch("https://google.com");
        if (resp.ok) {
            const body = yield resp.text();
            return body;
        }
        else {
            throw Error("Cannot fetch goog");
        }
    });
}
(() => __awaiter(void 0, void 0, void 0, function* () {
    let k = yield getTextOrBust(4);
    console.log(k);
}))();
