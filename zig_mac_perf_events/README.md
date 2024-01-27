##  A Zig wrapper/library for profiling Zig code using PMC (Performance Monitoring Counters) on MacOS

Based on the work of [Prof Lemire](https://lemire.me/blog/2021/03/24/counting-cycles-and-instructions-on-the-apple-m1-processor/), this is an attempt to create a Zig library that can be imported in projects to profile code

I first [ported](https://gist.github.com/GoWind/71bb85a2a09f4df6b9a49cd5403194b6) Prof Lemire's code from C++ to C (because I absolutely hate C++ with a passion) 
The `sgemm_ref.c` file can be compiled and run with perf counting using:

```
gcc sgemm_ref.c -o sgemm_ref
sudo ./sgemm_ref
```

You will need sudo for accessing the Performance counters on ARM Macs.

The C header file `m1pro_events.h` is portable across M2 (and M3 I presume) Macs as well, despite the `m1` in the header name
