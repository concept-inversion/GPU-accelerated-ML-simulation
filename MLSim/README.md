## Building the simulator
This repo includes the docker image for the simulator. To get the executables, build the docker image with command: 

`docker build -t MLSim`
 
The executable for the simulator can be found inside the build folder. 

## Running the simulator
The arguments to run the simulator are listed below: 

`./build/trt_n_simulator <trace> <aux_trace> <inference_engine> <Total instructions to simulation from trace> <Batchsize per GPU> <number of GPUs> <Warmup instruction>`

Here, 
both <trace> and <aux trace> represent the benchmarks pre-processed data in binary format. 
The repo includes 557.xz_r.qq100m.tr.bin and 557.xz_r.qq100m.tra.bin which consists of 1000 instructions as an example. 
<Warmup instructions> specifies how many instructions to simulate for warmup from each partition. 

For e.g., 
./build/trt_n_simulator 557.xz_r.qq100m.tr.bin 557.xz_r.qq100m.tra.bin ~/new_tensorrt_models/CNN3_32768_half.engine 1000 4 1 5 
This will run simulation on 557.xz_r benchmark with a CNN3 model having a batchsize of 4 on a single GPU. Here, The warmup length is 5. 

  
  ## Regenerating the results 
  The scripts required to regenerate the results in the paper can be found in the `scripts/` folder. 
  
  1. To generate state-of-the-art results, the script state_of_the_art.py can be used. The script generates the results for Figure 10 in the paper. It will report average throughput of each benchmark for the proposed system. 
  
  `python3 scripts/state_of_the_art.py`
  
  2. For the scalability study reported in the Figure 17, the script at scalability.py can be used. The script generates the throughput for each benchmark with various number of GPUs used to generate the figure. The number of GPUs to be used can be modified in the script to desired number. 
  
  `python3 scripts/scalability.py`
  
  3. For the parallel simulation error in the Figure 18, the script scripts/error.py can be used. The script reports the predicted latency for the program without any error correction, with warmup and with both warmup and correction for all the benchmarks. To get the actual error comparison with gem5, scripts/result_analysis.py can be used. The scripts contains the results from gem5 and reports the average error.

`python3 scripts/error.py`
