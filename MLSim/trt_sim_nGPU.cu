#include <memory>
#include <vector>
#include <iostream>
#include <fstream>
#include <cstring>
#include <string>
#include <cassert>
#include <cmath>
#include <sys/time.h>
#include <omp.h>
#include "wtime.h"
#include "herror.h"
#include "trt.cuh"
#include "sim.cuh"
#include "first_layer/custom.cuh"
//#include <boost/filesystem.hpp>
//##include <filename>
using namespace std;
#define NO_MEAN

#define GPU
#define WARP
//#define DEBUG

//#define Total_Trace 1024

Tick Num = 0;



void first( One_DConv *layer, int batch , char *w, char *b){
   One_DConv layer_host;
   layer_host.init(50,128,3,2,12800,128,batch,w,b);
   H_ERR(cudaMemcpy(layer, &layer_host, sizeof(One_DConv), cudaMemcpyHostToDevice));
   //H_ERR(cudaMalloc((void **)&X_device, sizeof(float)*111*50));
   //Conv_thread<<<int(batch/4),196>>>(layer, X_device,batch);   
    //H_ERR(cudaDeviceSynchronize());
}







void display(float *data, int size, int rows)
{
  for (int i = 0; i < rows; i++)
  {
    for (int j = 0; j < size; j++)
    {
      printf("%.2f\t", data[i * size + j]);
    }
    printf("\n");
  }
}

void display(unsigned long *data, int size, int rows)
{
  for (int i = 0; i < rows; i++)
  {
    for (int j = 0; j < size; j++)
    {
      printf("%.f\t", (float)data[i * size + j]);
    }
    printf("\n");
  }
}

float *read_numbers(char *fname, int sz)
{
  float *ret = new float[sz];
  ifstream in(fname);
  //printf("Trying to read from %s\n", fname);
  for (int i = 0; i < sz; i++)
    in >> ret[i];
  return ret;
}


int main(int argc, char *argv[])
{
  //printf("args count: %d\n", argc);
#ifdef CLASSIFY
  if (argc != 9)
  {
    cerr << "Usage: ./simulator_q <trace> <aux trace> <lat module> <class module> <variances> <# inst> <Total trace>" << endl;
    return 0;
  }
#else
  if (argc != 7)
  {
    cerr << "Usage: ./simulator_q <trace> <aux trace> <lat module> <#Insts> <ROB_per_GPU> <nGPUs>" << endl;
#endif
  return 0;
}
int arg_idx = 4;

for (int i = 0; i < TD_SIZE; i++) {
        zeros[i]=0;
      	default_val[i] = 0;
  }
  for (int i = TD_SIZE; i < ML_SIZE; i++)
    default_val[i] = default_val[i % TD_SIZE];

  const unsigned long long int nGPUs= atoi(argv[6]);
  const unsigned long long int ROB_per_GPU= atoi(argv[5]);
  int count[2];
  H_ERR(cudaGetDeviceCount(count));
  if (count[0] < nGPUs) {
   cerr << "GPUs not enough" << endl;
   return 0;
  }
//printf("GPU loaded\n");
//cout<<"Max threads: "<<omp_get_max_threads()<<endl;
unsigned long long int Total_Trace = nGPUs * ROB_per_GPU;
unsigned long long int Instructions = atoi(argv[4]);
std::string model_path(argv[3]);
TRTUniquePtr<nvinfer1::ICudaEngine> engine[nGPUs]{nullptr};
TRTUniquePtr<nvinfer1::IExecutionContext> context[nGPUs]{nullptr};
float *inputPtr[nGPUs], *output[nGPUs];
std::vector<nvinfer1::Dims> input_dims[nGPUs];
std::vector<nvinfer1::Dims> output_dims[nGPUs];
omp_set_num_threads(omp_get_max_threads());
//omp_set_num_threads(1);

#pragma omp parallel for
	for (int j = 0; j < nGPUs; j++) {
	    int pid= omp_get_thread_num();
	    //if(pid==0){cout<<omp_get_num_threads()<<endl;}
	    H_ERR(cudaSetDevice(j));
	    deseralizer(engine[j], context[j], model_path);
for (size_t i = 0; i < engine[j]->getNbBindings(); ++i)
{
  auto binding_size = getSizeByDim(engine[j]->getBindingDimensions(i)) * sizeof(float);
  std::cout<<"Index: "<<i<<" Binding_size: "<<binding_size<< " Engine binding Dim 0: "<<engine[j]->getBindingDimensions(i).d[0]<<" Dim 1: "<<engine[j]->getBindingDimensions(i).d[1]<< "\n";
  //cudaMalloc(&buffers[i], binding_size);
  if (engine[j]->bindingIsInput(i))
  {
    input_dims[j].emplace_back(engine[j]->getBindingDimensions(i));
  }
  else
  {
    output_dims[j].emplace_back(engine[j]->getBindingDimensions(i));
  }
}
if (input_dims[j].empty() || output_dims[j].empty())
{
  std::cerr << "Expect at least one input and one output for network\n";
}
//std::cout<<"Input dims: "<< input_dims[j] << ", output dims: "<<output_dims[j] << endl;
//float *inputPtr[nGPUs], *output[nGPUs];
}
int output_dim= engine[0]->getBindingDimensions(1).d[1];
//cout<< "output dim: "<< output_dim << endl;
One_DConv *layer_device;
float *X_device;
H_ERR(cudaMalloc((void **)&layer_device, sizeof(One_DConv)));
H_ERR(cudaMalloc((void **)&X_device, sizeof(float)*Total_Trace*111*50));
first(layer_device,Total_Trace,"l1_w","l1_b");


float *trace;
Tick *aux_trace;
//printf("Instr: %lu, trace: %d, mem: %lu \n",Instructions,TRACE_DIM, Instructions*TRACE_DIM);
int Batch_size = Instructions / Total_Trace;
if(Instructions%Total_Trace!=0){
	//printf("Prev bsize: %d, mew bsize: %d\n", Batch_size, Batch_size + 1);
	Batch_size= Batch_size +1;
	unsigned long long int new_instr=  (Batch_size+1)*Total_Trace;
	trace = (float *)malloc(TRACE_DIM * new_instr * sizeof(float));
	aux_trace = (Tick *)malloc(AUX_TRACE_DIM * new_instr* sizeof(Tick));
	unsigned long long int index= Instructions;
	for (index; index<new_instr; index++){
		memcpy(&trace[index * TRACE_DIM], zeros, sizeof(float)*TRACE_DIM);
		memcpy(&aux_trace[index * AUX_TRACE_DIM], zeros, sizeof(Tick)*AUX_TRACE_DIM);
		index+=1;
		//trace+= TRACE_DIM; aux_trace+= AUX_TRACE_DIM;
	}
}
else {
	trace = (float *)malloc(TRACE_DIM * Instructions * sizeof(float));
	aux_trace = (Tick *)malloc(AUX_TRACE_DIM * Instructions * sizeof(Tick));
}
read_trace_mem(argv[1], argv[2], trace, aux_trace, Instructions);
//unsigned long long int new_instr=  (Batch_size+1)*Total_Trace;
//printf("Batchsize: %d, instructions supported: %lu\n", Batch_size, Batch_size * Total_Trace);
//printf("Remaining instr: %lu\n",Instructions-new_instr);

//trace = (float *)malloc(TRACE_DIM * new_instr * sizeof(float));
//aux_trace = (Tick *)malloc(AUX_TRACE_DIM * new_instr* sizeof(Tick));
//omp_set_num_threads(96);
double measured_time = 0.0;
int *fetched_inst_num = new int[Total_Trace];
int *fetched = new int[Total_Trace];
int *ROB_flag = new int[Total_Trace];
float *trace_all[Total_Trace];
Tick *aux_trace_all[Total_Trace];
//printf("variable init\n");
struct timeval s,e;
#pragma omp parallel for
	for (int i = 0; i < Total_Trace; i++){  
   	unsigned long long int offset = i * Batch_size;
	//printf("Trace: %d, offset: %d\n", i,offset);
  	trace_all[i] = trace + offset * TRACE_DIM;
  	aux_trace_all[i] = aux_trace + offset * AUX_TRACE_DIM;
     
     	}
int *status[nGPUs];
struct Inst *inst[nGPUs];
struct ROB *rob_d[nGPUs];
struct SQ *sq_d[nGPUs];
struct Inst *inst_d[nGPUs];
float *default_val_d[nGPUs];
void *buffers[nGPUs][2];
Tick *total_tick_d[nGPUs+1];
float *rand_inp;
H_ERR(cudaMalloc((void **)&rand_inp, sizeof(float)*Total_Trace*7168));
#pragma omp parallel for
   for (int i = 0; i < nGPUs; i++) {
      gettimeofday(&s, NULL);
      time_t s_time = (s.tv_sec * 1000) + (s.tv_usec / 1000);
      int pid= omp_get_thread_num(); 
      inst[i]= new Inst[ROB_per_GPU];
      H_ERR(cudaSetDevice(i));
      H_ERR(cudaMalloc((void **)&total_tick_d[i], sizeof(Tick)));
      H_ERR(cudaMalloc((void **)&status[i], sizeof(int) * ROB_per_GPU));
      H_ERR(cudaMalloc((void **)&rob_d[i], sizeof(ROB)*ROB_per_GPU));
      H_ERR(cudaMalloc((void **)&sq_d[i], sizeof(SQ)*ROB_per_GPU));
      H_ERR(cudaMalloc((void **)&inst_d[i], sizeof(Inst)*ROB_per_GPU));
      H_ERR(cudaMalloc((void **)&inputPtr[i], sizeof(float) * (ML_SIZE) * ROB_per_GPU));
      H_ERR(cudaMalloc((void **)&output[i], sizeof(float) * ROB_per_GPU * output_dim));
      buffers[i][0]= inputPtr[i];
      buffers[i][1]= output[i];
      cudaMemset(inputPtr[i], 0, (ML_SIZE+WIDTH*TD_SIZE));
      // For factor, mean and default values
      H_ERR(cudaMalloc((void **)&default_val_d[i], sizeof(float) * (TD_SIZE)));
      H_ERR(cudaMemcpy(default_val_d[i], &default_val, sizeof(float) * TD_SIZE, cudaMemcpyHostToDevice));
}

struct timeval total_start, total_end;
int iteration = 0;
double start_ = wtime();
double red=0,pre=0, tr=0,inf=0,upd=0;
#ifdef DEBUG
FILE *pFile;
pFile= fopen ("trtcustom.bin", "wb");
#endif
//printf("Check: %.2f\n", trace_all[0][Instructions*TRACE_DIM-1]);
gettimeofday(&total_start, NULL);
initialization<<<4096,32>>>(rob_d[0], Total_Trace);
H_ERR(cudaDeviceSynchronize());
int N_flag=0;
while (iteration < Batch_size){
  //if((iteration % 50)==0){
  //cout << "\nIteration: " << iteration << endl;
  double st = wtime();
  
#pragma omp parallel for
  for (int i = 0; i < Total_Trace; i++)
  {
    //cout<<"I: "<<i<<endl;
    int GPU_ID= i/ROB_per_GPU;
    int index= i % ROB_per_GPU;
    //printf("I: %d,index: %d, Instruction: %lu\n", i, index, iteration + i * Batch_size);
    //printf("I: %d, GPU: %d, index: %d, ROB: %d\n", i, GPU_ID, index, ROB_per_GPU);
    if ((GPU_ID >= nGPUs) || (index > ROB_per_GPU)){printf("Error...\n");}
    if (!inst[GPU_ID][index].read_sim_mem(trace_all[i], aux_trace_all[i],0))
    {cout << "Error\n";}
    trace_all[i] += TRACE_DIM; aux_trace_all[i] += AUX_TRACE_DIM;
  } 
    double check1 = wtime();
    red+= (check1-st);
    //cout<< "Instructions read\n";
struct timeval s1, s2;
#pragma omp parallel for
  for (int i = 0; i < nGPUs; i++) {
     int pid= omp_get_thread_num();
     gettimeofday(&s1, NULL);
     time_t s_time = (s1.tv_sec * 1000) + (s1.tv_usec / 1000);
     H_ERR(cudaSetDevice(i));
     H_ERR(cudaMemcpy(inst_d[i], inst[i], sizeof(Inst) * ROB_per_GPU, cudaMemcpyHostToDevice));
    //double t1= wtime();
    //printf("I: %d, Input: %p, Output: %p\n",i,inputPtr[i],output[i]);
    //double t1= wtime();
    //preprocess<<<4096, 64>>>(rob_d[i], sq_d[i], inst_d[i], default_val_d[i], inputPtr[i], status[i], ROB_per_GPU);
    H_ERR(cudaDeviceSynchronize());
    //double check3= wtime();
    //pre+= check3-t1;
    //cout << "Preprocess done\n";
    //double check3= wtime();
    //if(iteration!=0){pre+= (check3-t1);}
    //cout<< (check3-t1) << endl;    
    // fwrite(inp, sizeof(float), ML_SIZE, pFile); 
    //printf("I: %d, buffer: %p, buffer[0]: %p, buffer[1]: %p\n",i,buffers[i], buffers[i][0], buffers[i][1]);
    //double t1= wtime();
    N_flag= iteration % WIDTH;
    //int input_offset= (WIDTH-N_flag-1)*TD_SIZE;
    cout<<buffers[i][0]<<endl;
    //buffers[i][0]= inputPtr[i] + input_offset;
    cout<<buffers[i][0]<<endl;
    //Conv_thread<<<int(Total_Trace/2),128>>>(layer_device, X_device,Total_Trace, N_flag);
    //__global__ void transpose(float *input, float *output, int shift, int batch){
    double t1= wtime();
    transpose<<<480,128>>>(inputPtr[i],output[i],N_flag, Total_Trace);
    H_ERR(cudaDeviceSynchronize());
    double check3= wtime();
    pre+= check3-t1;
    cout<<"Trans:" << ((check3-t1)/Total_Trace)*1000000 << endl;
    t1= wtime();
    context[i]->enqueueV2(buffers[i], 0, nullptr);
    H_ERR(cudaStreamSynchronize(0));
    check3= wtime();
    cout<<"inf: " << ((check3-t1)/Total_Trace)*1000000 << endl;
    //cout<<"Inference done\n";
    //printf("I: %d, Input: %p, Output: %p\n",i,inputPtr[i],output[i]);
    //update<<<4096,64>>>(rob_d[i], sq_d[i],output[i], inputPtr[i], status[i], ROB_per_GPU, output_dim);
    H_ERR(cudaDeviceSynchronize());
    gettimeofday(&s2, NULL);
    time_t e_time = (s2.tv_sec * 1000) + (s2.tv_usec / 1000);
    //printf("GPU: %d, st: %lu, en: %lu\n",i,s_time,e_time);
    }
  double check5=wtime(); 
  //pre+= (check5-check1);
  iteration++;
  gettimeofday(&e, NULL);
  time_t e_time = (s.tv_sec * 1000) + (s.tv_usec / 1000);
   //cout<<"Trace: "<<i<<", Stime: " << s_time <<", etime: " << e_time<<endl;    
}
printf("Avg time: %f\n",(pre/Instructions)*1000000);
//return 0;
#ifdef DEBUG
  fclose(pFile);
#endif
  //boost::filesystem::path d(argv[1]);
  //cout<<d.filename().string()<<", ";
  string p(argv[3]);
  string d(argv[2]);
  size_t found= p.find_last_of("/\\");
  cout<<p.substr(found+1)<<",";
  found= d.find_last_of("/\\");
  cout<< d.substr(found+1) <<",";
  printf("%.4f,%.4f,",red/Instructions*1000000, pre/Instructions*1000000);
  //printf("%.4f, %.4f, %.4f, %.4f, %.4f\n",red, tr, pre, inf, upd);
//printf("%.4f, %.4f, %.4f, %.4f, %.4f\n",red/Instructions*1000000, tr/Instructions*1000000, pre/Instructions*1000000, inf/Instructions*1000000, upd/Instructions*1000000);
double end_ = wtime();
/*
for (int a=0; a<nGPUs; a++){

	for (void *buf : buffers[a])
{
  cudaFree(buf);
}}
*/
gettimeofday(&total_end, NULL);
Tick agg_tick=0;
//Tick *total_tick= new Tick[nGPUs];
Tick *total_tick = (Tick*) malloc((nGPUs+1)*sizeof(Tick));
for(int i=0; i<nGPUs; i++){
  H_ERR(cudaSetDevice(i));
  result<<<1, 1>>>(rob_d[i], ROB_per_GPU, Instructions, total_tick_d[i]);
  H_ERR(cudaDeviceSynchronize());
  total_tick[i]=0;
  H_ERR(cudaMemcpy(&total_tick[i], total_tick_d[i], sizeof(Tick), cudaMemcpyDeviceToHost));
  //cout<< total_tick[i] << endl;
  agg_tick+= total_tick[i];
}
//H_ERR(cudaDeviceSynchronize());
double total_time = total_end.tv_sec - total_start.tv_sec + (total_end.tv_usec - total_start.tv_usec) / 1000000.0;
//cout << "Total time: " << (end_ - start_) << endl;
#ifdef RUN_TRUTH
cout << "Truth"
     << "\n";
#endif
//cout << Instructions << " instructions finish by " << (curTick - 1) << "\n";
cout << total_time << ","<< ROB_per_GPU <<","<< nGPUs<<"," ;
cout << agg_tick<< ",";
cout << Instructions / total_time / 1000000.0 << "\n";
//cout << "USPI: " << total_time * 1000000.0 / Instructions << "\n";
//cout << "Trace: " << argv[1] << "\n";
#ifdef CLASSIFY
cout << "Model: " << argv[3] << " ,GPUs: " << nGPUs << "\n";
#else
  //cout << "Lat Model: " << argv[3] << "\n";
#endif
return agg_tick;
}
