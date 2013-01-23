
#include <iostream>
#include "ftocmacros.h"
#include "omp.h"
#include "cuda_common.cu"

#include "chunk_cuda.cu"
extern CloverleafCudaChunk chunk;

__global__ void device_accelerate_kernel_cuda
(int x_min,int x_max,int y_min,int y_max, double dbyt,
const double* __restrict const xarea,
const double* __restrict const yarea,
const double* __restrict const volume,
const double* __restrict const density0,
const double* __restrict const pressure,
const double* __restrict const viscosity,
const double* __restrict const xvel0,
const double* __restrict const yvel0,
      double* __restrict const xvel1,
      double* __restrict const yvel1)
{
    __kernel_indexes;

    double nodal_mass, step_by_mass;

    // prevent writing to *vel1, then read from it, then write to it again
    double xvel_temp, yvel_temp;

    if(row >= (x_min + 1) && row <= (y_max + 1) + 1
    && column >= (x_min + 1) && column <= (x_max + 1) + 1)
    {
        nodal_mass =
            (density0[THARR2D(-1, -1, 0)] * volume[THARR2D(-1, -1, 0)]
            + density0[THARR2D(0, -1, 0)] * volume[THARR2D(0, -1, 0)]
            + density0[THARR2D(0, 0, 0)] * volume[THARR2D(0, 0, 0)]
            + density0[THARR2D(-1, 0, 0)] * volume[THARR2D(-1, 0, 0)])
            * 0.25;

        step_by_mass = 0.5 * dbyt / nodal_mass;

        // x velocities
        xvel_temp = xvel0[THARR2D(0, 0, 1)] - step_by_mass
            * (xarea[THARR2D(0, 0, 1)] * (pressure[THARR2D(0, 0, 0)] - pressure[THARR2D(-1, 0, 0)])
            + xarea[THARR2D(0, -1, 1)] * (pressure[THARR2D(0, -1, 0)] - pressure[THARR2D(-1, -1, 0)]));

        xvel1[THARR2D(0, 0, 1)] = xvel_temp - step_by_mass
            * (xarea[THARR2D(0, 0, 1)] * (viscosity[THARR2D(0, 0, 0)] - viscosity[THARR2D(-1, 0, 0)])
            + xarea[THARR2D(0, -1, 1)] * (viscosity[THARR2D(0, -1, 0)] - viscosity[THARR2D(-1, -1, 0)]));

        // y velocities
        yvel_temp = yvel0[THARR2D(0, 0, 1)] - step_by_mass
            * (yarea[THARR2D(0, 0, 0)] * (pressure[THARR2D(0, 0, 0)] - pressure[THARR2D(0, -1, 0)])
            + yarea[THARR2D(-1, 0, 0)] * (pressure[THARR2D(-1, 0, 0)] - pressure[THARR2D(-1, -1, 0)]));

        yvel1[THARR2D(0, 0, 1)] = yvel_temp - step_by_mass
            * (yarea[THARR2D(0, 0, 0)] * (viscosity[THARR2D(0, 0, 0)] - viscosity[THARR2D(0, -1, 0)])
            + yarea[THARR2D(-1, 0, 0)] * (viscosity[THARR2D(-1, 0, 0)] - viscosity[THARR2D(-1, -1, 0)]));

    }
    
}

extern "C" void accelerate_kernel_cuda_
(int *xmin,int *xmax,int *ymin,int *ymax,
double *dbyt,
double *xarea,double *yarea,
double *volume,
double *density0,
double *pressure,
double *viscosity,
double *xvel0,
double *yvel0,
double *xvel1,
double *yvel1,
double *unused_array)
{
    chunk.accelerate_kernel(*dbyt);
}

void CloverleafCudaChunk::accelerate_kernel
(double dbyt)
{
_CUDA_BEGIN_PROFILE_name(device);

    device_accelerate_kernel_cuda<<< num_blocks, BLOCK_SZ >>>
    (x_min, x_max, y_min, y_max, dbyt, xarea, yarea, volume, density0,
        pressure, viscosity, xvel0, yvel0, xvel1, yvel1);
    errChk(__LINE__, __FILE__);

_CUDA_END_PROFILE_name(device);
}
