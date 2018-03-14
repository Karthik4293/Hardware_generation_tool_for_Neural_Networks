# HDL Script Generation tool for Neural Networks

The Project aims to generate a piece of hardware for a multi-layer network.
The system will take a multiplier budget (i.e., the maximum number of multipliers your design may use) as input
as well as the dimensions for each of the three layers.

The generator will use this information to choose how parallel to make each of the layers.

Instructions to follow:

1. To run the testbench generator, run
./testgen 1 M N 1 T

2. This will produce four files:
• tb_layer_M_N_1_T.sv the testbench file
• tb_layer_M_N_1_T.in the inputs to test
• tb_layer_M_N_1_T.exp the expected results
• const_M_N_1_T.txt the constants to give your generator
Then, you would generate the accompanying code with:
./gen 1 M N 1 T const_M_N_1_T.txt

3. Simulate and observe the waveforms using Vsim and Vlog commands

4. Generated scripts can be tested using scripts testmode1 and testmode2
