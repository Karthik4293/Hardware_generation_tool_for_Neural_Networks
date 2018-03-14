//////////////////////////////////////////////////////////////////////////////////////////////////////////
// ESE 507 Project 3 Code
// Fall 2017
// Professor Peter Milder
// Team: Reynerio Rubio and Karthik Raj
//////////////////////////////////////////////////////////////////////////////////////////////////////////
#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <cstdlib>
#include <cstring>
#include <assert.h>
#include <math.h>
using namespace std;

void printUsage();
void genLayer(int M, int N, int P, int bits, vector<int>& constvector, string modName, ofstream &os);
void genAllLayers(int N, int M1, int M2, int M3, int mult_budget, int bits, vector<int>& constVector, string modName, ofstream &os);
void readConstants(ifstream &constStream, vector<int>& constvector);
void genROM(vector<int>& constVector, int bits, string modName, ofstream &os);

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//					main function
//////////////////////////////////////////////////////////////////////////////////////////////////////////
int main(int argc, char* argv[]) {

   // If the user runs the program without enough parameters, print a helpful message
   // and quit.
   if (argc < 7) {
      printUsage();
      return 1;
   }

   int mode = atoi(argv[1]);

   ifstream const_file;
   ofstream os;
   vector<int> constVector;

   //----------------------------------------------------------------------
   // Look here for Part 1 and 2
   if ((mode == 1) && (argc == 7)) {
      // Mode 1: Generate one layer with given dimensions and one testbench

      // --------------- read parameters, etc. ---------------
      int M = atoi(argv[2]);
      int N = atoi(argv[3]);
      int P = atoi(argv[4]);
      int bits = atoi(argv[5]);
      const_file.open(argv[6]);
      if (const_file.is_open() != true) {
         cout << "ERROR reading constant file " << argv[6] << endl;
         return 1;
      }

      // Read the constants out of the provided file and place them in the constVector vector
      readConstants(const_file, constVector);

      string out_file = "layer_" + to_string(M) + "_" + to_string(N) + "_" + to_string(P) + "_" + to_string(bits) + ".sv";

      os.open(out_file);
      if (os.is_open() != true) {
         cout << "ERROR opening " << out_file << " for write." << endl;
         return 1;
      }
      // -------------------------------------------------------------

      // call the genLayer function you will write to generate this layer
      string modName = "layer_" + to_string(M) + "_" + to_string(N) + "_" + to_string(P) + "_" + to_string(bits);
      genLayer(M, N, P, bits, constVector, modName, os);

   }
   //--------------------------------------------------------------------


   // ----------------------------------------------------------------
   // Look here for Part 3
   else if ((mode == 2) && (argc == 9)) {
      // Mode 2: Generate three layer with given dimensions and interconnect them

      // --------------- read parameters, etc. ---------------
      int N  = atoi(argv[2]);
      int M1 = atoi(argv[3]);
      int M2 = atoi(argv[4]);
      int M3 = atoi(argv[5]);
      int mult_budget = atoi(argv[6]);
      int bits = atoi(argv[7]);
      const_file.open(argv[8]);
      if (const_file.is_open() != true) {
         cout << "ERROR reading constant file " << argv[8] << endl;
         return 1;
      }
      readConstants(const_file, constVector);

      string out_file = "network_" + to_string(N) + "_" + to_string(M1) + "_" + to_string(M2) + "_" + to_string(M3) + "_" + to_string(mult_budget) + "_" + to_string(bits) + ".sv";


      os.open(out_file);
      if (os.is_open() != true) {
         cout << "ERROR opening " << out_file << " for write." << endl;
         return 1;
      }
      // -------------------------------------------------------------

      string mod_name = "network_" + to_string(N) + "_" + to_string(M1) + "_" + to_string(M2) + "_" + to_string(M3) + "_" + to_string(mult_budget) + "_" + to_string(bits);

      // call the genAllLayers function
      genAllLayers(N, M1, M2, M3, mult_budget, bits, constVector, mod_name, os);

   }
   //-------------------------------------------------------

   else {
      printUsage();
      return 1;
   }

   // close the output stream
   os.close();

}

// Read values from the constant file into the vector
void readConstants(ifstream &constStream, vector<int>& constvector) {
   string constLineString;
   while(getline(constStream, constLineString)) {
      int val = atoi(constLineString.c_str());
      constvector.push_back(val);
   }
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//					genROM function
//////////////////////////////////////////////////////////////////////////////////////////////////////////
// Generate a ROM based on values constVector.
// Values should each be "bits" number of bits.
void genROM(vector<int>& constVector, int bits, string modName, ofstream &os) {

      int numWords = constVector.size();
      int addrBits = ceil(log2(numWords));

      os << "module " << modName << "(clk, addr, z);" << endl;
      os << "   input clk;" << endl;
      os << "   input [" << addrBits-1 << ":0] addr;" << endl;
      os << "   output logic signed [" << bits-1 << ":0] z;" << endl;
      os << "   always_ff @(posedge clk) begin" << endl;
      os << "      case(addr)" << endl;
      int i=0;
      for (vector<int>::iterator it = constVector.begin(); it < constVector.end(); it++, i++) {
         if (*it < 0)
            os << "        " << i << ": z <= -" << bits << "'d" << abs(*it) << ";" << endl;
         else
            os << "        " << i << ": z <= "  << bits << "'d" << *it      << ";" << endl;
      }
      os << "      endcase" << endl << "   end" << endl << "endmodule" << endl << endl;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//					genLayer function
//////////////////////////////////////////////////////////////////////////////////////////////////////////
void genLayer(int M, int N, int P, int bits, vector<int>& constVector, string modName, ofstream &os) {
	// Check there are enough values in the constant file.
	if (M*N+M > constVector.size()) {
		cout << "ERROR: constVector does not contain enough data for the requested design" << endl;
		cout << "The design parameters requested require " << M*N+M << " numbers, but the provided data only have " << constVector.size() << " constants" << endl;
		assert(false);
	}

	// Generate a ROM (for W) with constants 0 through M*N-1, with "bits" number of bits

	vector<int> wVector(&constVector[0], &constVector[M*N]);
	int w_numWords = wVector.size();
	int w_addrBits = ceil(log2(w_numWords));
	string rom_w_modName = modName + "_W_rom";
	// Generate a ROM (for B) with constants M*N through M*N+M-1 wits "bits" number of bits

	vector<int> bVector(&constVector[M*N], &constVector[M*N+M]);
	int b_numWords = bVector.size();
	int b_addrBits = ceil(log2(b_numWords));
	string rom_b_modName = modName + "_B_rom";


	int x_numWords = N;
	int x_addrBits = ceil(log2(x_numWords));

	int y_numWords = M;
	int y_addrBits = ceil(log2(y_numWords));
	// Make your module name: layer_M_N_P_bits, where these parameters are replaced with the
	// actual numbers
	//////////////////////////////////////////////////////////////////////////////////////////////////////////
	//					layer_M_N_P_T module
	//////////////////////////////////////////////////////////////////////////////////////////////////////////
    os << "module " << modName << "(clk, reset, s_valid, m_ready, data_in, m_valid, s_ready, data_out);" << endl;
	os << "\tparameter T = "<< bits << ";" << endl;
	os << "\tinput clk, reset, s_valid, m_ready;" << endl;
	os << "\tinput signed ["<< bits - 1 << ":0]\tdata_in;" << endl;
	os << "\toutput logic signed ["<< bits - 1 << ":0]\tdata_out;" << endl;
	os << "\toutput m_valid, s_ready;" << endl;
	os << endl;

  	os << "\tlogic signed["<< bits - 1 << ":0] ";
  	for (int i = 1; i <= P; i++){
        if (i < P)
                os << "data_out" << i << ", ";
        else if (i==P)
                os << "data_out" << i << " ;" << endl;
    }

	os << "\tlogic ";
  	for (int i = 1; i <= P; i++){
        if (i < P)
            os << "m_valid" << i << ", ";
        else if (i==P)
                os << "m_valid" << i << " ;" << endl;
        }
	os << "\tlogic ";
	for (int i = 1; i <= P; i++){
		if (i < P)
			os << "s_ready" << i << ", ";
		else if (i==P)
			os << "s_ready" << i << " ;" << endl;
	}

  	os << "\tlogic [" << P-1 << ":0] out_count;" <<  endl;
  	os << endl;

  	for (int i = 0; i< P; i++) {
		os << "\tmvma_" << modName <<  "#(.rank(" << i << "))  " << "mvma_" << M << "_" << N << "_" << i+1 << "(clk, reset, s_valid, m_ready, data_in, m_valid" << i+1 <<", s_ready"<< i+1 <<", data_out"<<i+1 << ");" << endl;
  	}
	os << endl;

	os << "\t assign m_valid = (" ;
  	for (int i = 1; i <= P; i++){
		if (i < P)
			os << "m_valid" << i << " || " ;
		else if (i==P)
			os << "m_valid" << i << " );" << endl;
	}

  	os << "\t assign s_ready = (" ;
  	for (int i = 1; i <= P; i++){
  		if (i < P)
     			os << "s_ready" << i << " || " ;
  		else if (i==P)
    			os << "s_ready" << i << " );" << endl;
	}
  	os << endl;

	os << "\talways_ff @ (posedge clk) begin" << endl;
  	os << "\t\tif (reset == 1)" << endl;
 	os << "\t\t\tout_count <= 1;" << endl;
  	os << "\t\tif (m_valid && m_ready) begin " << endl;
 	os << "\t\t\tif (out_count != "<< P << " )" << endl;
 	os << "\t\t\t\tout_count <= out_count + 1;" << endl;
 	os << "\t\t\telse" << endl;
 	os << "\t\t\t\tout_count <= 1;" << endl;
  	os << "\t\tend" << endl;
  	os << "\tend" << endl;
  	os << endl;

  	os << "\talways_comb begin" << endl;
  	for (int i = 1; i <= P ; i++){
    		if (i == 1){
    			os << "\t\tif (out_count == " << i << " ) " << endl;
    			os << "\t\t\tdata_out = data_out" << i << " ;"<<endl;
  		}
    			else {
    			os << "\t\telse if (out_count == " << i << " ) " << endl;
    			os << "\t\t\tdata_out = data_out" << i << " ;"<<endl;
  		}
  	}
    	os << "\t\telse" << endl;
    	os << "\t\t\tdata_out = 0;" << endl;
    	os << "\tend" << endl;

	os << "endmodule" << endl << endl;

	//////////////////////////////////////////////////////////////////////////////////////////////////////////
	//					mvma module
	//////////////////////////////////////////////////////////////////////////////////////////////////////////
   // for (int i = 0; i< P; i++) {
	//	os << "\tmvma" <<  "#(.rank(" << i << "))  " << "mvma_" << M << "_" << N << "_" << i+1 << "(clk, reset, s_valid, //m_ready, data_in, m_valid" << i+1 <<", s_ready"<< i+1 <<", data_out"<<i+1 << ");" << endl;
  	//}
	//os << endl;
    
    
	//os << "module mvma_" << M << "_" << N << "_" << P <<"(clk, reset, s_valid, m_ready, data_in, m_valid, s_ready, data_out);" << endl;
    os << "module mvma_" << modName<<"(clk, reset, s_valid, m_ready, data_in, m_valid, s_ready, data_out);" << endl;
	os << "\tinput\t\t\tclk, reset, s_valid, m_ready;" << endl;
	os << "\tinput signed ["<< bits - 1 << ":0]\tdata_in;" << endl;
	os << "\toutput signed ["<< bits - 1 << ":0]\tdata_out;" << endl;
	os << "\toutput\t\t\tm_valid, s_ready;" << endl;
	os << "\tlogic [" << w_addrBits -1 << ":0]\t\taddr_w;" << endl;
	os << "\tlogic [" << x_addrBits -1 << ":0]\t\taddr_x;" << endl;
	os << "\tlogic [" << b_addrBits -1 << ":0]\t\taddr_b;" << endl;
	os << "\tlogic\t\t\twr_en_x, accum_src, enable_accum;" << endl;
	os << "\tlogic [" << x_addrBits << ":0]\t\toutput_counter;" << endl;
 	os << "\tparameter rank;" << endl;
 	os << endl;

	os << "\tcontrol_"<<modName << "#(.rank(rank))" << "\t\t\tctrl(clk, reset, s_valid, m_ready, addr_x, wr_en_x, addr_w, accum_src, m_valid, s_ready, enable_accum, addr_b, output_counter);" << endl;
	os << "\tdatapath_"<< modName <<"\t\tdpth(clk, reset, data_in, addr_x, wr_en_x, addr_w, accum_src, data_out, enable_accum, addr_b, output_counter);" << endl;
	os << "endmodule" << endl << endl;

	//////////////////////////////////////////////////////////////////////////////////////////////////////////
	//					control module
	//////////////////////////////////////////////////////////////////////////////////////////////////////////
	os << "module control_" << modName<< "(clk, reset, s_valid, m_ready, addr_x, wr_en_x, addr_w, accum_src, m_valid, s_ready, accum_en, addr_b, output_counter);" << endl;
	os << "\tinput\t\t\tclk, reset, s_valid, m_ready; " << endl;
	os << "\toutput logic [" << w_addrBits -1 << ":0]\taddr_w;" << endl;
	os << "\toutput logic [" << x_addrBits -1 << ":0]\taddr_x;" << endl;
	os << "\toutput logic [" << b_addrBits -1 << ":0]\taddr_b;" << endl;
	os << "\toutput logic\t\twr_en_x, accum_src, m_valid, s_ready, accum_en;" << endl;
	os << endl;

    os << "\tlogic [" << P << ":0] d,c;" << endl;
    os << "\tlogic [" << bits - 1 << ":0] input_buffer;" << endl;
    os << endl;

	os << "\tlogic\t\t\tcomputing, temp;" << endl;
	os << "\tlogic [" << x_addrBits << ":0]\t\tinput_counter;"  << endl;
	os << "\toutput logic [" << x_addrBits<< ":0]\toutput_counter;" << endl;
    os << "\tlogic [" << x_addrBits << ":0]  count;" << endl;
    os << "\tlogic [" << y_addrBits << ":0] block;" << endl;
    os << "\tparameter T=" << bits << ", M=" << M << ", N=" << N << ", P=" << P << ", rank;" << endl;
	os << endl;

	os << "\talways_comb begin" << endl;
	os << "\t\tif( (s_valid == 1) && (s_ready == 1) && (input_counter < " << N << ") )" << endl;
	os << "\t\t\twr_en_x = 1;" << endl;
	os << "\t\telse" << endl;
	os << "\t\t\twr_en_x = 0;" << endl;
    os << endl;
    os << "\t\tif ((reset == 1) || (c ==" << P << "))" << endl;
    os << "\t\t    d = 1;" << endl;
    os << "\t\telse" << endl;
    os << "\t\t    d = c + 1;" << endl;
	os << "\tend" << endl;
	os << endl;

	os << "\talways_ff @(posedge clk) begin" << endl;
 	os << "\t\tif(reset ==1) begin" << endl;
	os << "\t\t\ts_ready <= 1;" << endl;
	os << "\t\t\taddr_x <= 0;" << endl;
	os << "\t\t\taddr_w <= rank*(" << N << ");" << endl;
	os << "\t\t\taddr_b <= rank;" << endl;
	os << "\t\t\taccum_src <= 1;" << endl;
	os << "\t\t\tcomputing <= 0;" << endl;
	os << "\t\t\tinput_counter <= 0;" << endl;
	os << "\t\t\toutput_counter <= 0;" << endl;
	os << "\t\t\taccum_en <= 1;" << endl;
	os << "\t\t\tm_valid <= 0;" << endl;
    os << "\t\t\tblock <= rank;" << endl;
    os << "\t\t\tcount <= 1;" << endl;
    os << "\t\t\tc <= 0;" << endl;
    os << "\t\t\ttemp <= 1;" << endl;
    os << "\t\t\tinput_buffer <= 0;" << endl;
	os << "\t\tend" << endl;
	os << endl;
	os << endl;

	os << "\t\telse if (computing == 0) begin" << endl;
    os << "\t\t\tc <= 0;" << endl;
    os << "\t\t\tif (c == P)" << endl;
    os << "\t\t\t\t output_counter <= 0;" << endl;
    os << "\t\t\tif ((input_buffer % (M/P) == 0) || (input_buffer == 0)) begin" << endl;
	os << "\t\t\t\tif (s_valid == 1) begin" << endl;
	os << "\t\t\t\t\tif (input_counter < " << N << ") begin" << endl;
	os << "\t\t\t\t\t\tif (addr_x == " << N-1 << ")" << endl;
	os << "\t\t\t\t\t\t\taddr_x <= 0;" << endl;
	os << "\t\t\t\t\telse" << endl;
	os << "\t\t\t\t\t\taddr_x <= addr_x + 1;" << endl;
	os << "\t\t\t\t\tinput_counter <= input_counter + 1;" << endl;
    os << "\t\t\t\t\tend" << endl;
	os << "\t\t\t\t\tif (input_counter == " << N-1 << ") begin" << endl;
	os << "\t\t\t\t\t\tinput_counter <= 0;" << endl;
	os << "\t\t\t\t\t\ts_ready <= 0;" << endl;
	os << "\t\t\t\t\t\tcomputing <= 1;" << endl;
    os << "\t\t\t\t\t\ttemp <= 1;" << endl;
	os << "\t\t\t\t\tend" << endl;
	os << "\t\t\t\tend" << endl;
	os << "\t\t\tend" << endl;
    os << "\t\t\telse begin " << endl;
    os << "\t\t\t\t input_counter <= 0;" << endl;
    os << "\t\t\t\t computing <= 1;" << endl;
    os << "\t\t\t\t temp <= 1;" << endl;
	os << "\t\t\tend" << endl;
    os << "\t\tend" << endl;
	os << endl;
	os << endl;

	os << "\t\telse if (computing == 1) begin" << endl;
    os << endl;
    os << "\t\t\tif (temp == 1) begin" << endl;
    os << "\t\t\t\t input_buffer <= input_buffer + 1;" << endl;
    os << "\t\t\t\t temp <= 0;" << endl;
    os << "\t\t\tend" << endl;
    os << endl;

	os << "\t\t\tif ((m_valid == 1) && (m_ready == 1))" << endl;
	os << "\t\t\t\t c <= d;" << endl;
    os << endl;

	os << "\t\t\tif (output_counter < " << N+2 << ")" << endl;
	os << "\t\t\t\toutput_counter <= output_counter + 1;" << endl;
	os << endl;

	os << "\t\t\tif ((m_valid == 1) && (m_ready == 1) && (d == P))" << endl;
	os << "\t\t\t\taccum_src <= 1;" << endl;
	os << "\t\t\telse if (output_counter == 0)" << endl;
	os << "\t\t\t\taccum_src <= 0;" << endl;
	os << endl;

    os << "\t\t\tif (count > N) begin" << endl;
    os << "\t\t\t\t count <= 1;" << endl;
    os << "\t\t\t\t block <= block + P;" << endl;
    os << "\t\t\tend" << endl;
    os << endl;

  os << "\t\t\tif ( block > M-1) begin" << endl;
  os << "\t\t\t\t block <= rank;" << endl;
  os << "\t\t\t\t addr_w <= rank*(N);" << endl;
  os << "\t\t\t\t count <= 1;" << endl;
  os << "\t\t\tend" << endl;
	os << "\t\t\tif (output_counter < " << N<< ") begin" << endl;
    os << endl;
    os << "\t\t\t\taddr_w <= block*(N) + count;" << endl;
    os << "\t\t\t\tcount <= count + 1;" << endl;
    os << endl;
	os << "\t\t\t\tif (addr_w == (N*(M + rank - P + 1)) - 1)" << endl;
	os << "\t\t\t\t\taddr_w <= rank;" << endl;
    os << endl;


	os << "\t\t\t\tif (addr_x == " << N-1 << ")" << endl;
	os << "\t\t\t\t\taddr_x <= 0;" << endl;
	os << "\t\t\t\telse" << endl;
	os << "\t\t\t\t\taddr_x <= addr_x + 1;" << endl;
	os << "\t\t\tend" << endl;
	os << endl;

	os << "\t\t\tif (output_counter == " << N + 1 << ") begin" << endl;
	os << "\t\t\t\tif (addr_b == (M*N)-(P-1-rank))" << endl;
	os << "\t\t\t\t\taddr_b <= rank;" << endl;
	os << "\t\t\t\telse" << endl;
  os << "\t\t\t\t\tif (block <= M-1) begin" << endl;
	os << "\t\t\t\t\t\taddr_b <= addr_b + P;" << endl;
  os << "\t\t\t\t\t\taddr_w <= block*N;" << endl;
	os << "\t\t\t\tend" << endl;
  os << "\t\t\t\t\telse" << endl;
  os << "\t\t\t\t\t\taddr_b <= rank;" << endl;
  os << "\t\t\tend" << endl;
	os << endl;


	os << "\t\t\tif (output_counter == " << N +1 << ")" << endl;
	os << "\t\t\t\taccum_en <= 0;" << endl;
	os << endl;

	os << "\t\t\tif ((m_valid == 1) && (m_ready == 1) && (d == P))" << endl;
	os << "\t\t\t\tm_valid <= 0;" << endl;
	os << "\t\t\telse if (output_counter == " << N +1 << ")" << endl;
	os << "\t\t\t\tm_valid <= 1;" << endl;
	os << endl;


	os << "\t\t\tif ((m_valid == 1) && (m_ready == 1) && (d == P)) begin" << endl;
	os << "\t\t\t\tcomputing <= 0;" << endl;
	os << "\t\t\t\tif (input_buffer % (M/P) == 0)" << endl;
    os << "\t\t\t\t\ts_ready <= 1;" << endl;
    os << "\t\t\t\telse " << endl;
    os << "\t\t\t\t\ts_ready <= 0;" << endl;
	os << "\t\t\tend" << endl;
    os << endl;
    os << "\t\tend" << endl;

    os << "\t\tif  (c == P)  begin" << endl;
    os << "\t\t\t accum_en <= 1;" << endl;
	os << "\t\tend" << endl;
    os << endl;
	os << "\tend" << endl;
	os << "endmodule" << endl << endl;

	//////////////////////////////////////////////////////////////////////////////////////////////////////////
	//					memory
	//////////////////////////////////////////////////////////////////////////////////////////////////////////
	os << "module " <<"memory_" << modName << "(clk, data_in, data_out, addr, wr_en);" << endl;
	os << "\tparameter WIDTH = 16, SIZE = 64, LOGSIZE = 6;" << endl;
	os << "\tinput [WIDTH-1:0]\t\tdata_in;" << endl;
	os << "\toutput logic [WIDTH-1:0]\tdata_out;" << endl;
	os << "\tinput [LOGSIZE-1:0]\t\taddr;" << endl;
	os << "\tinput\t\t\t\tclk, wr_en;" << endl;
	os << "\tlogic [SIZE-1:0][WIDTH-1:0]\tmem;" << endl;
	os << "\talways_ff @(posedge clk) begin" << endl;
	os << "\t\tdata_out <= mem[addr];" << endl;
	os << "\t\tif (wr_en)" << endl;
	os << "\t\t\tmem[addr] <= data_in;" << endl;
	os << "\tend" << endl;
	os << "endmodule" << endl << endl;

	//////////////////////////////////////////////////////////////////////////////////////////////////////////
	//					ROMS
	//////////////////////////////////////////////////////////////////////////////////////////////////////////

	genROM(wVector, bits, rom_w_modName, os);
	genROM(bVector, bits, rom_b_modName, os);


	//////////////////////////////////////////////////////////////////////////////////////////////////////////
	//					datapath
	//////////////////////////////////////////////////////////////////////////////////////////////////////////
	os << "module " <<"datapath_" << modName<<"(clk, reset, data_in, addr_x, wr_en_x, addr_w, accum_src, data_out, enable_accum, addr_b, output_counter);" << endl;
	os << "\tinput\t\t\t\tclk, reset, wr_en_x, accum_src, enable_accum;" << endl;
	os << "\tinput signed [" << bits - 1 << ":0]\t\tdata_in;" << endl;
	os << "\tinput [" << w_addrBits -1 << ":0]\t\t\taddr_w;" << endl;
	os << "\tinput [" << x_addrBits -1 << ":0]\t\t\taddr_x;" << endl;
	os << "\tinput [" << b_addrBits -1 << ":0]\t\t\taddr_b;" << endl;
	os << "\tinput [" << x_addrBits << ":0]\t\t\toutput_counter;" << endl;
	os << endl;
	os << "\toutput logic signed [" << bits - 1 << ":0]\tdata_out;" << endl;
	os << "\tlogic signed [" << bits - 1<< ":0]\t\tdata_out_x, data_out_w, data_out_b;" << endl;
	os << "\tlogic signed [" << bits - 1 << ":0]\t\tmult_out, add_out, mux_out, mult_out_temp;" << endl;
	os << endl;
	os << "\tmemory_" << modName<< "#(" << bits << ", " <<  N << ", " << x_addrBits <<")\t\tmem_x(clk, data_in, data_out_x, addr_x, wr_en_x);" << endl;
	os << "\t"<< rom_w_modName << "\t\trom_w(clk, addr_w, data_out_w);" << endl;
	os << "\t"<< rom_b_modName << "\t\trom_b(clk, addr_b, data_out_b);" << endl;
	os << endl;
	os << "\tassign mult_out_temp = (output_counter < " << N + 1<< "&& output_counter != 0) ? data_out_x * data_out_w : 0;" << endl;
	os << endl;
	os << "\talways_comb begin" << endl;
	os << endl;
	os << "\t\tif (accum_src == 1 || output_counter <= 1) begin" << endl;
    os << "\t\t\tadd_out = 0;" << endl;
	os << "\t\t\tmux_out = data_out_b;" << endl;
	os << "\t\tend" << endl;
	os << "\t\telse begin" << endl;
	os << "\t\t\tadd_out  = mult_out  + data_out;" << endl;
	os << "\t\t\tmux_out = add_out;" << endl;
	os << "\t\tend" << endl;
    os << "\tend" << endl;
	os << endl;

	os << "\talways_ff @(posedge clk) begin" << endl;
	os << "\t\tmult_out <= mult_out_temp;" << endl;
	os << "\t\tif (reset == 1) begin" << endl;
	os << "\t\t\tdata_out <= 0;" << endl;
	os << "\t\tend" << endl;
	os << "\t\telse if (enable_accum == 1) begin" << endl;
	os << "\t\t\tif (output_counter == " << N +1 << ") begin" << endl;
	os << "\t\t\t\tif (mux_out > 0)" << endl;
	os << "\t\t\t\t\tdata_out <= mux_out;" << endl;
	os << "\t\t\t\telse" << endl;
	os << "\t\t\t\t\tdata_out <= 0;" << endl;
	os << "\t\t\tend" << endl;
	os << "\t\t\telse" << endl;
	os << "\t\t\t\tdata_out <= mux_out;" << endl;
	os << "\t\tend" << endl;
	os << endl;
	os << "\tend" << endl;

	os << "endmodule" << endl << endl;
}

// Part 3: Generate a hardware system with three layers interconnected.
// Layer 1: Input length: N, output length: M1
// Layer 2: Input length: M1, output length: M2
// Layer 3: Input length: M2, output length: M3
// mult_budget is the number of multipliers your overall design may use.
// Your goal is to build the fastest design that uses mult_budget or fewer multipliers
// constVector holds all the constants for your system (all three layers, in order)
void genAllLayers(int N, int M1, int M2, int M3, int mult_budget, int bits, vector<int>& constVector, string modName, ofstream &os) {

   // Here you will write code to figure out the best values to use for P1, P2, and P3, given
   // mult_budget.
   int P1 = 1;
   int P2 = 1;
   int P3 = 1;
   int mult_budget_temp = mult_budget;
   //while(mult_budget_temp > 0){
        //if divisible, give some parallelism to P1, and decrement the budget
        
   //     if((M1 % (P1+1) == 0) && (mult_budget_temp >0)){
   //        P1 = P1 + 1;
   //        mult_budget_temp--; 
    //    }
        //if divisible, give some parallelism to P2, and decrement the budget
    //    if((M2 % (P2+1) == 0) && (mult_budget_temp >0)){
    //       P2 = P2 + 1;
    //       mult_budget_temp--; 
    //    }
        //if divisible, give some parallelism to P3, and decrement the budget
     //  if((M3 % (P3+1) == 0) && (mult_budget_temp >0)){
     //      P3 = P3 + 1;
     //      mult_budget_temp--; 
     //   }
       
  // }
       
  // }
   // output top-level module
   // set your top-level name to "network_top"
   os << "module network_" << N << "_" << M1 << "_" << M2 << "_" << M3 << "_" << mult_budget << "_" << bits << "(clk , reset, s_valid, m_ready, data_in, m_valid, s_ready, data_out);" << endl;
   os << "\tparameter T = "<< bits << ";" << endl;
   os << "\tinput clk, reset, s_valid, m_ready;" << endl;
   os << "\tinput signed ["<< bits - 1 << ":0]\tdata_in;" << endl;
   os << "\toutput logic signed ["<< bits - 1 << ":0]\tdata_out;" << endl;
   os << "\toutput m_valid, s_ready;" << endl;
   os << endl;

   os << "\tlogic [" << bits -1 << ":0]\t data_out_1, data_out_2;" << endl;
   os << "\tlogic m_valid_1, m_valid_2, s_ready_2, s_ready_3;" << endl;
   os << endl;

   os << "\tlayer1_" << (M1) << "_" << (N) << "_" << (P1) << "_" << (bits) << " layer1(clk, reset, s_valid, s_ready_2, data_in, m_valid_1 ,s_ready, data_out_1);" << endl;
   os << "\tlayer2_" << (M2) << "_" << (M1) << "_" << (P2) << "_" << (bits) << " layer2(clk, reset, m_valid_1, s_ready_3, data_out_1, m_valid_2 ,s_ready_2, data_out_2);" << endl;
   os << "\tlayer3_" << (M3) << "_" << (M2) << "_" << (P3) << "_" << (bits) << " layer3(clk, reset, m_valid_2, m_ready, data_out_2, m_valid ,s_ready_3, data_out);" << endl;
   os << "endmodule" << endl;

   // -------------------------------------------------------------------------
   // Split up constVector for the three layers
   // layer 1's W matrix is M1 x N and its B vector has size M1
   int start = 0;
   int stop = M1*N+M1;
   vector<int> constVector1(&constVector[start], &constVector[stop]);

   // layer 2's W matrix is M2 x M1 and its B vector has size M2
   start = stop;
   stop = start+M2*M1+M2;
   vector<int> constVector2(&constVector[start], &constVector[stop]);

   // layer 3's W matrix is M3 x M2 and its B vector has size M3
   start = stop;
   stop = start+M3*M2+M3;
   vector<int> constVector3(&constVector[start], &constVector[stop]);

   if (stop > constVector.size()) {
      cout << "ERROR: constVector does not contain enough data for the requested design" << endl;
      cout << "The design parameters requested require " << stop << " numbers, but the provided data only have " << constVector.size() << " constants" << endl;
      assert(false);
   }
   // --------------------------------------------------------------------------


   // generate the three layer modules
   string subModName = "layer1_" + to_string(M1) + "_" + to_string(N) + "_" + to_string(P1) + "_" + to_string(bits);
   genLayer(M1, N, P1, bits, constVector1, subModName, os);

   subModName = "layer2_" + to_string(M2) + "_" + to_string(M1) + "_" + to_string(P2) + "_" + to_string(bits);
   genLayer(M2, M1, P2, bits, constVector2, subModName, os);

   subModName = "layer3_" + to_string(M3) + "_" + to_string(M2) + "_" + to_string(P3) + "_" + to_string(bits);
   genLayer(M3, M2, P3, bits, constVector3, subModName, os);

   // You will need to add code in the module at the top of this function to stitch together insantiations of these three modules

}


void printUsage() {
  cout << "Usage: ./gen MODE ARGS" << endl << endl;

  cout << "   Mode 1: Produce one neural network layer and testbench (Part 1 and Part 2)" << endl;
  cout << "      ./gen 1 M N P bits const_file" << endl;
  cout << "      Example: produce a neural network layer with a 4 by 5 matrix, with parallelism 1" << endl;
  cout << "               and 16 bit words, with constants stored in file const.txt" << endl;
  cout << "                   ./gen 1 4 5 1 16 const.txt" << endl << endl;

  cout << "   Mode 2: Produce a system with three interconnected layers with four testbenches (Part 3)" << endl;
  cout << "      Arguments: N, M1, M2, M3, mult_budget, bits, const_file" << endl;
  cout << "         Layer 1: M1 x N matrix" << endl;
  cout << "         Layer 2: M2 x M1 matrix" << endl;
  cout << "         Layer 3: M3 x M2 matrix" << endl;
  cout << "              e.g.: ./gen 2 4 5 6 7 15 16 const.txt" << endl << endl;
}
