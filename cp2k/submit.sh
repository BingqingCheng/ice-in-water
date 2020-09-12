#!/bin/bash -l
#
# CP2K on Piz Daint
#SBATCH -A s957
#SBATCH --job-name=cp2k
#SBATCH --time=08:00:00
#SBATCH --nodes=8
#SBATCH --ntasks-per-node=12
#SBATCH --cpus-per-task=1
#SBATCH --partition=normal
#SBATCH --constraint=gpu


#========================================
# load modules and run simulation
module load daint-gpu
module load CP2K

export CRAY_CUDA_MPS=1
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
ulimit -s unlimited

prefix=$1
scale=$2

port=$$
porttmp=$(echo $scale | sed 's/\.//')
maxmemory=$(echo "$SLURM_JOB_NUM_NODES*32000" | bc )

#  Adds the address of the server to the i-pi input

sed -e 's/address>[^<]*</address> '${HOSTNAME}' </' -e "s/PORT/${porttmp}/" -e "s/SCALE/${scale}/" -e "s/PREFIX/${prefix}/" ice.xml > ${prefix}-scale-${scale}.xml
python   ~/source/i-pi-mc/bin/i-pi ${prefix}-scale-${scale}.xml &> log-${prefix}-scale-${scale}.i-pi &

sleep 10

# Launches CP2K.
sed -e '/MAX_MEMORY/c\          MAX_MEMORY '${maxmemory}'' -e '/HOST/c\    HOST '${HOSTNAME}'' -e '/PORT/c\    PORT '19${porttmp}'' -e "s/SCALE-SCALE/${scale}/" ice.cp2k > ${prefix}-scale-${scale}.cp2k
ABC=$(head -n 2 replicated_relax_geometry_scale_${scale}-pos_0.xyz | tail -n 1 | awk '{print $3,$4,$5}')
ANGLES=$(head -n 2 replicated_relax_geometry_scale_${scale}-pos_0.xyz | tail -n 1 | awk '{print $6,$7,$8}')
sed -i -e "s/SIZEABC/${ABC}/" -e "s/SIZEANGLE/${ANGLES}/" ${prefix}-scale-${scale}.cp2k

srun -n $SLURM_NTASKS  cp2k.psmp ${prefix}-scale-${scale}.cp2k &> log-${prefix}-scale-${scale}.cp2k &


wait
