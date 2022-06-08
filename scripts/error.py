import sys
import os
import numpy as np
import time


'''
./build/trt_n_simulator /raid/data/spandey/qq_traces/557.xz_r.qq100m.tr.bin /raid/data/spandey/qq_traces/557.xz_r.qq100m.tra.bin ~/new_tensorrt_models/CNN3_32768_half.engine 100000000 32768 8
'''

datasets= ['554.roms_r','997.specrand_fr', '507.cactuBSSN_r', '531.deepsjeng_r', '538.imagick_r',
        '505.mcf_r',
        '519.lbm_r',
        '521.wrf_r',
        '523.xalancbmk_r',
        '525.x264_r',
        '526.blender_r',
        '527.cam4_r',
        '544.nab_r',
        '548.exchange2_r',
        '549.fotonik3d_r',
        '999.specrand_ir',
        '557.xz_r'
                ]
nGPUs= [1]
batchsize= [32768]
instructions= ' 100000000 '
warmups= [0,110]
correction= [0,1]
#executables= ['libtorch_simulator_warmup']
executables= ['trt_n_simulator']
models= ['CNN3_F_3_2_128_2_1_2_256_2_0_2_256_2_0_1_040821_best.pt']
loc= '~/datasets/'
loc_trace=  loc+ 'qq_traces/' 
loc_aux= loc+'aux_traces/'
for bsize in batchsize:
    for GPU in nGPUs:
        for dataset in datasets:
            for executable in executables:
                for model in models:
                    for warmup in warmups:
                        for correct in correction:
                            os.system('./build/' +executable+ loc_trace +dataset+ '.qq100m.tr.bin'+loc_aux +dataset+ '.qq100m.tra.bin ~/final_libtorch_models/' +model+instructions+' ' + str(bsize)+' ' + str(GPU) +' '+str(warmup) +' ' + str(correction))
