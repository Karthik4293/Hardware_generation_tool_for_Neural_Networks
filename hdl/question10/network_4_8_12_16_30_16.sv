module network_4_8_12_16_30_16(clk , reset, s_valid, m_ready, data_in, m_valid, s_ready, data_out);
	parameter T = 16;
	input clk, reset, s_valid, m_ready;
	input signed [15:0]	data_in;
	output logic signed [15:0]	data_out;
	output m_valid, s_ready;

	logic [15:0]	 data_out_1, data_out_2;
	logic m_valid_1, m_valid_2, s_ready_2, s_ready_3;

	layer1_8_4_1_16 layer1(clk, reset, s_valid, s_ready_2, data_in, m_valid_1 ,s_ready, data_out_1);
	layer2_12_8_1_16 layer2(clk, reset, m_valid_1, s_ready_3, data_out_1, m_valid_2 ,s_ready_2, data_out_2);
	layer3_16_12_1_16 layer3(clk, reset, m_valid_2, m_ready, data_out_2, m_valid ,s_ready_3, data_out);
endmodule
module layer1_8_4_1_16(clk, reset, s_valid, m_ready, data_in, m_valid, s_ready, data_out);
	parameter T = 16;
	input clk, reset, s_valid, m_ready;
	input signed [15:0]	data_in;
	output logic signed [15:0]	data_out;
	output m_valid, s_ready;

	logic signed[15:0] data_out1 ;
	logic m_valid1 ;
	logic s_ready1 ;
	logic [0:0] out_count;

	mvma_layer1_8_4_1_16#(.rank(0))  mvma_8_4_1(clk, reset, s_valid, m_ready, data_in, m_valid1, s_ready1, data_out1);

	 assign m_valid = (m_valid1 );
	 assign s_ready = (s_ready1 );

	always_ff @ (posedge clk) begin
		if (reset == 1)
			out_count <= 1;
		if (m_valid && m_ready) begin 
			if (out_count != 1 )
				out_count <= out_count + 1;
			else
				out_count <= 1;
		end
	end

	always_comb begin
		if (out_count == 1 ) 
			data_out = data_out1 ;
		else
			data_out = 0;
	end
endmodule

module mvma_layer1_8_4_1_16(clk, reset, s_valid, m_ready, data_in, m_valid, s_ready, data_out);
	input			clk, reset, s_valid, m_ready;
	input signed [15:0]	data_in;
	output signed [15:0]	data_out;
	output			m_valid, s_ready;
	logic [4:0]		addr_w;
	logic [1:0]		addr_x;
	logic [2:0]		addr_b;
	logic			wr_en_x, accum_src, enable_accum;
	logic [2:0]		output_counter;
	parameter rank;

	control_layer1_8_4_1_16#(.rank(rank))			ctrl(clk, reset, s_valid, m_ready, addr_x, wr_en_x, addr_w, accum_src, m_valid, s_ready, enable_accum, addr_b, output_counter);
	datapath_layer1_8_4_1_16		dpth(clk, reset, data_in, addr_x, wr_en_x, addr_w, accum_src, data_out, enable_accum, addr_b, output_counter);
endmodule

module control_layer1_8_4_1_16(clk, reset, s_valid, m_ready, addr_x, wr_en_x, addr_w, accum_src, m_valid, s_ready, accum_en, addr_b, output_counter);
	input			clk, reset, s_valid, m_ready; 
	output logic [4:0]	addr_w;
	output logic [1:0]	addr_x;
	output logic [2:0]	addr_b;
	output logic		wr_en_x, accum_src, m_valid, s_ready, accum_en;

	logic [1:0] d,c;
	logic [15:0] input_buffer;

	logic			computing, temp;
	logic [2:0]		input_counter;
	output logic [2:0]	output_counter;
	logic [2:0]  count;
	logic [3:0] block;
	parameter T=16, M=8, N=4, P=1, rank;

	always_comb begin
		if( (s_valid == 1) && (s_ready == 1) && (input_counter < 4) )
			wr_en_x = 1;
		else
			wr_en_x = 0;

		if ((reset == 1) || (c ==1))
		    d = 1;
		else
		    d = c + 1;
	end

	always_ff @(posedge clk) begin
		if(reset ==1) begin
			s_ready <= 1;
			addr_x <= 0;
			addr_w <= rank*(4);
			addr_b <= rank;
			accum_src <= 1;
			computing <= 0;
			input_counter <= 0;
			output_counter <= 0;
			accum_en <= 1;
			m_valid <= 0;
			block <= rank;
			count <= 1;
			c <= 0;
			temp <= 1;
			input_buffer <= 0;
		end


		else if (computing == 0) begin
			c <= 0;
			if (c == P)
				 output_counter <= 0;
			if ((input_buffer % (M/P) == 0) || (input_buffer == 0)) begin
				if (s_valid == 1) begin
					if (input_counter < 4) begin
						if (addr_x == 3)
							addr_x <= 0;
					else
						addr_x <= addr_x + 1;
					input_counter <= input_counter + 1;
					end
					if (input_counter == 3) begin
						input_counter <= 0;
						s_ready <= 0;
						computing <= 1;
						temp <= 1;
					end
				end
			end
			else begin 
				 input_counter <= 0;
				 computing <= 1;
				 temp <= 1;
			end
		end


		else if (computing == 1) begin

			if (temp == 1) begin
				 input_buffer <= input_buffer + 1;
				 temp <= 0;
			end

			if ((m_valid == 1) && (m_ready == 1))
				 c <= d;

			if (output_counter < 6)
				output_counter <= output_counter + 1;

			if ((m_valid == 1) && (m_ready == 1) && (d == P))
				accum_src <= 1;
			else if (output_counter == 0)
				accum_src <= 0;

			if (count > N) begin
				 count <= 1;
				 block <= block + P;
			end

			if ( block > M-1) begin
				 block <= rank;
				 addr_w <= rank*(N);
				 count <= 1;
			end
			if (output_counter < 4) begin

				addr_w <= block*(N) + count;
				count <= count + 1;

				if (addr_w == (N*(M + rank - P + 1)) - 1)
					addr_w <= rank;

				if (addr_x == 3)
					addr_x <= 0;
				else
					addr_x <= addr_x + 1;
			end

			if (output_counter == 5) begin
				if (addr_b == (M*N)-(P-1-rank))
					addr_b <= rank;
				else
					if (block <= M-1) begin
						addr_b <= addr_b + P;
						addr_w <= block*N;
				end
					else
						addr_b <= rank;
			end

			if (output_counter == 5)
				accum_en <= 0;

			if ((m_valid == 1) && (m_ready == 1) && (d == P))
				m_valid <= 0;
			else if (output_counter == 5)
				m_valid <= 1;

			if ((m_valid == 1) && (m_ready == 1) && (d == P)) begin
				computing <= 0;
				if (input_buffer % (M/P) == 0)
					s_ready <= 1;
				else 
					s_ready <= 0;
			end

		end
		if  (c == P)  begin
			 accum_en <= 1;
		end

	end
endmodule

module memory_layer1_8_4_1_16(clk, data_in, data_out, addr, wr_en);
	parameter WIDTH = 16, SIZE = 64, LOGSIZE = 6;
	input [WIDTH-1:0]		data_in;
	output logic [WIDTH-1:0]	data_out;
	input [LOGSIZE-1:0]		addr;
	input				clk, wr_en;
	logic [SIZE-1:0][WIDTH-1:0]	mem;
	always_ff @(posedge clk) begin
		data_out <= mem[addr];
		if (wr_en)
			mem[addr] <= data_in;
	end
endmodule

module layer1_8_4_1_16_W_rom(clk, addr, z);
   input clk;
   input [4:0] addr;
   output logic signed [15:0] z;
   always_ff @(posedge clk) begin
      case(addr)
        0: z <= -16'd109;
        1: z <= -16'd31;
        2: z <= 16'd46;
        3: z <= 16'd73;
        4: z <= 16'd86;
        5: z <= 16'd50;
        6: z <= -16'd39;
        7: z <= 16'd69;
        8: z <= -16'd44;
        9: z <= -16'd24;
        10: z <= -16'd26;
        11: z <= -16'd50;
        12: z <= -16'd59;
        13: z <= 16'd62;
        14: z <= -16'd97;
        15: z <= -16'd92;
        16: z <= -16'd17;
        17: z <= -16'd29;
        18: z <= -16'd123;
        19: z <= -16'd21;
        20: z <= -16'd101;
        21: z <= -16'd115;
        22: z <= -16'd57;
        23: z <= -16'd123;
        24: z <= -16'd63;
        25: z <= 16'd18;
        26: z <= -16'd88;
        27: z <= 16'd123;
        28: z <= 16'd80;
        29: z <= 16'd103;
        30: z <= 16'd8;
        31: z <= 16'd99;
      endcase
   end
endmodule

module layer1_8_4_1_16_B_rom(clk, addr, z);
   input clk;
   input [2:0] addr;
   output logic signed [15:0] z;
   always_ff @(posedge clk) begin
      case(addr)
        0: z <= -16'd56;
        1: z <= -16'd74;
        2: z <= 16'd44;
        3: z <= -16'd97;
        4: z <= 16'd104;
        5: z <= -16'd122;
        6: z <= 16'd100;
        7: z <= -16'd67;
      endcase
   end
endmodule

module datapath_layer1_8_4_1_16(clk, reset, data_in, addr_x, wr_en_x, addr_w, accum_src, data_out, enable_accum, addr_b, output_counter);
	input				clk, reset, wr_en_x, accum_src, enable_accum;
	input signed [15:0]		data_in;
	input [4:0]			addr_w;
	input [1:0]			addr_x;
	input [2:0]			addr_b;
	input [2:0]			output_counter;

	output logic signed [15:0]	data_out;
	logic signed [15:0]		data_out_x, data_out_w, data_out_b;
	logic signed [15:0]		mult_out, add_out, mux_out, mult_out_temp;

	memory_layer1_8_4_1_16#(16, 4, 2)		mem_x(clk, data_in, data_out_x, addr_x, wr_en_x);
	layer1_8_4_1_16_W_rom		rom_w(clk, addr_w, data_out_w);
	layer1_8_4_1_16_B_rom		rom_b(clk, addr_b, data_out_b);

	assign mult_out_temp = (output_counter < 5&& output_counter != 0) ? data_out_x * data_out_w : 0;

	always_comb begin

		if (accum_src == 1 || output_counter <= 1) begin
			add_out = 0;
			mux_out = data_out_b;
		end
		else begin
			add_out  = mult_out  + data_out;
			mux_out = add_out;
		end
	end

	always_ff @(posedge clk) begin
		mult_out <= mult_out_temp;
		if (reset == 1) begin
			data_out <= 0;
		end
		else if (enable_accum == 1) begin
			if (output_counter == 5) begin
				if (mux_out > 0)
					data_out <= mux_out;
				else
					data_out <= 0;
			end
			else
				data_out <= mux_out;
		end

	end
endmodule

module layer2_12_8_1_16(clk, reset, s_valid, m_ready, data_in, m_valid, s_ready, data_out);
	parameter T = 16;
	input clk, reset, s_valid, m_ready;
	input signed [15:0]	data_in;
	output logic signed [15:0]	data_out;
	output m_valid, s_ready;

	logic signed[15:0] data_out1 ;
	logic m_valid1 ;
	logic s_ready1 ;
	logic [0:0] out_count;

	mvma_layer2_12_8_1_16#(.rank(0))  mvma_12_8_1(clk, reset, s_valid, m_ready, data_in, m_valid1, s_ready1, data_out1);

	 assign m_valid = (m_valid1 );
	 assign s_ready = (s_ready1 );

	always_ff @ (posedge clk) begin
		if (reset == 1)
			out_count <= 1;
		if (m_valid && m_ready) begin 
			if (out_count != 1 )
				out_count <= out_count + 1;
			else
				out_count <= 1;
		end
	end

	always_comb begin
		if (out_count == 1 ) 
			data_out = data_out1 ;
		else
			data_out = 0;
	end
endmodule

module mvma_layer2_12_8_1_16(clk, reset, s_valid, m_ready, data_in, m_valid, s_ready, data_out);
	input			clk, reset, s_valid, m_ready;
	input signed [15:0]	data_in;
	output signed [15:0]	data_out;
	output			m_valid, s_ready;
	logic [6:0]		addr_w;
	logic [2:0]		addr_x;
	logic [3:0]		addr_b;
	logic			wr_en_x, accum_src, enable_accum;
	logic [3:0]		output_counter;
	parameter rank;

	control_layer2_12_8_1_16#(.rank(rank))			ctrl(clk, reset, s_valid, m_ready, addr_x, wr_en_x, addr_w, accum_src, m_valid, s_ready, enable_accum, addr_b, output_counter);
	datapath_layer2_12_8_1_16		dpth(clk, reset, data_in, addr_x, wr_en_x, addr_w, accum_src, data_out, enable_accum, addr_b, output_counter);
endmodule

module control_layer2_12_8_1_16(clk, reset, s_valid, m_ready, addr_x, wr_en_x, addr_w, accum_src, m_valid, s_ready, accum_en, addr_b, output_counter);
	input			clk, reset, s_valid, m_ready; 
	output logic [6:0]	addr_w;
	output logic [2:0]	addr_x;
	output logic [3:0]	addr_b;
	output logic		wr_en_x, accum_src, m_valid, s_ready, accum_en;

	logic [1:0] d,c;
	logic [15:0] input_buffer;

	logic			computing, temp;
	logic [3:0]		input_counter;
	output logic [3:0]	output_counter;
	logic [3:0]  count;
	logic [4:0] block;
	parameter T=16, M=12, N=8, P=1, rank;

	always_comb begin
		if( (s_valid == 1) && (s_ready == 1) && (input_counter < 8) )
			wr_en_x = 1;
		else
			wr_en_x = 0;

		if ((reset == 1) || (c ==1))
		    d = 1;
		else
		    d = c + 1;
	end

	always_ff @(posedge clk) begin
		if(reset ==1) begin
			s_ready <= 1;
			addr_x <= 0;
			addr_w <= rank*(8);
			addr_b <= rank;
			accum_src <= 1;
			computing <= 0;
			input_counter <= 0;
			output_counter <= 0;
			accum_en <= 1;
			m_valid <= 0;
			block <= rank;
			count <= 1;
			c <= 0;
			temp <= 1;
			input_buffer <= 0;
		end


		else if (computing == 0) begin
			c <= 0;
			if (c == P)
				 output_counter <= 0;
			if ((input_buffer % (M/P) == 0) || (input_buffer == 0)) begin
				if (s_valid == 1) begin
					if (input_counter < 8) begin
						if (addr_x == 7)
							addr_x <= 0;
					else
						addr_x <= addr_x + 1;
					input_counter <= input_counter + 1;
					end
					if (input_counter == 7) begin
						input_counter <= 0;
						s_ready <= 0;
						computing <= 1;
						temp <= 1;
					end
				end
			end
			else begin 
				 input_counter <= 0;
				 computing <= 1;
				 temp <= 1;
			end
		end


		else if (computing == 1) begin

			if (temp == 1) begin
				 input_buffer <= input_buffer + 1;
				 temp <= 0;
			end

			if ((m_valid == 1) && (m_ready == 1))
				 c <= d;

			if (output_counter < 10)
				output_counter <= output_counter + 1;

			if ((m_valid == 1) && (m_ready == 1) && (d == P))
				accum_src <= 1;
			else if (output_counter == 0)
				accum_src <= 0;

			if (count > N) begin
				 count <= 1;
				 block <= block + P;
			end

			if ( block > M-1) begin
				 block <= rank;
				 addr_w <= rank*(N);
				 count <= 1;
			end
			if (output_counter < 8) begin

				addr_w <= block*(N) + count;
				count <= count + 1;

				if (addr_w == (N*(M + rank - P + 1)) - 1)
					addr_w <= rank;

				if (addr_x == 7)
					addr_x <= 0;
				else
					addr_x <= addr_x + 1;
			end

			if (output_counter == 9) begin
				if (addr_b == (M*N)-(P-1-rank))
					addr_b <= rank;
				else
					if (block <= M-1) begin
						addr_b <= addr_b + P;
						addr_w <= block*N;
				end
					else
						addr_b <= rank;
			end

			if (output_counter == 9)
				accum_en <= 0;

			if ((m_valid == 1) && (m_ready == 1) && (d == P))
				m_valid <= 0;
			else if (output_counter == 9)
				m_valid <= 1;

			if ((m_valid == 1) && (m_ready == 1) && (d == P)) begin
				computing <= 0;
				if (input_buffer % (M/P) == 0)
					s_ready <= 1;
				else 
					s_ready <= 0;
			end

		end
		if  (c == P)  begin
			 accum_en <= 1;
		end

	end
endmodule

module memory_layer2_12_8_1_16(clk, data_in, data_out, addr, wr_en);
	parameter WIDTH = 16, SIZE = 64, LOGSIZE = 6;
	input [WIDTH-1:0]		data_in;
	output logic [WIDTH-1:0]	data_out;
	input [LOGSIZE-1:0]		addr;
	input				clk, wr_en;
	logic [SIZE-1:0][WIDTH-1:0]	mem;
	always_ff @(posedge clk) begin
		data_out <= mem[addr];
		if (wr_en)
			mem[addr] <= data_in;
	end
endmodule

module layer2_12_8_1_16_W_rom(clk, addr, z);
   input clk;
   input [6:0] addr;
   output logic signed [15:0] z;
   always_ff @(posedge clk) begin
      case(addr)
        0: z <= -16'd18;
        1: z <= -16'd54;
        2: z <= 16'd11;
        3: z <= 16'd51;
        4: z <= -16'd120;
        5: z <= 16'd42;
        6: z <= 16'd88;
        7: z <= -16'd9;
        8: z <= -16'd114;
        9: z <= 16'd93;
        10: z <= 16'd99;
        11: z <= -16'd87;
        12: z <= 16'd106;
        13: z <= -16'd86;
        14: z <= -16'd82;
        15: z <= -16'd85;
        16: z <= 16'd61;
        17: z <= -16'd42;
        18: z <= -16'd89;
        19: z <= 16'd13;
        20: z <= -16'd66;
        21: z <= 16'd47;
        22: z <= -16'd16;
        23: z <= 16'd6;
        24: z <= 16'd101;
        25: z <= -16'd100;
        26: z <= 16'd37;
        27: z <= 16'd77;
        28: z <= -16'd94;
        29: z <= 16'd10;
        30: z <= -16'd118;
        31: z <= 16'd16;
        32: z <= 16'd84;
        33: z <= 16'd21;
        34: z <= -16'd60;
        35: z <= 16'd93;
        36: z <= -16'd64;
        37: z <= -16'd100;
        38: z <= -16'd44;
        39: z <= -16'd50;
        40: z <= 16'd121;
        41: z <= -16'd73;
        42: z <= -16'd9;
        43: z <= 16'd99;
        44: z <= -16'd30;
        45: z <= 16'd38;
        46: z <= -16'd114;
        47: z <= -16'd97;
        48: z <= 16'd124;
        49: z <= -16'd75;
        50: z <= 16'd44;
        51: z <= -16'd70;
        52: z <= 16'd100;
        53: z <= -16'd100;
        54: z <= 16'd65;
        55: z <= 16'd73;
        56: z <= -16'd72;
        57: z <= -16'd26;
        58: z <= 16'd23;
        59: z <= -16'd37;
        60: z <= 16'd112;
        61: z <= 16'd33;
        62: z <= 16'd107;
        63: z <= 16'd69;
        64: z <= -16'd73;
        65: z <= -16'd81;
        66: z <= 16'd34;
        67: z <= -16'd9;
        68: z <= -16'd53;
        69: z <= 16'd118;
        70: z <= 16'd69;
        71: z <= -16'd60;
        72: z <= -16'd82;
        73: z <= -16'd68;
        74: z <= -16'd89;
        75: z <= 16'd16;
        76: z <= 16'd98;
        77: z <= -16'd74;
        78: z <= 16'd47;
        79: z <= 16'd95;
        80: z <= -16'd21;
        81: z <= -16'd37;
        82: z <= -16'd103;
        83: z <= -16'd48;
        84: z <= -16'd9;
        85: z <= 16'd90;
        86: z <= -16'd103;
        87: z <= 16'd47;
        88: z <= -16'd63;
        89: z <= 16'd48;
        90: z <= -16'd118;
        91: z <= -16'd79;
        92: z <= -16'd46;
        93: z <= 16'd118;
        94: z <= 16'd118;
        95: z <= 16'd9;
      endcase
   end
endmodule

module layer2_12_8_1_16_B_rom(clk, addr, z);
   input clk;
   input [3:0] addr;
   output logic signed [15:0] z;
   always_ff @(posedge clk) begin
      case(addr)
        0: z <= -16'd91;
        1: z <= 16'd24;
        2: z <= -16'd128;
        3: z <= -16'd15;
        4: z <= 16'd15;
        5: z <= 16'd69;
        6: z <= 16'd53;
        7: z <= 16'd61;
        8: z <= -16'd127;
        9: z <= 16'd93;
        10: z <= -16'd51;
        11: z <= 16'd100;
      endcase
   end
endmodule

module datapath_layer2_12_8_1_16(clk, reset, data_in, addr_x, wr_en_x, addr_w, accum_src, data_out, enable_accum, addr_b, output_counter);
	input				clk, reset, wr_en_x, accum_src, enable_accum;
	input signed [15:0]		data_in;
	input [6:0]			addr_w;
	input [2:0]			addr_x;
	input [3:0]			addr_b;
	input [3:0]			output_counter;

	output logic signed [15:0]	data_out;
	logic signed [15:0]		data_out_x, data_out_w, data_out_b;
	logic signed [15:0]		mult_out, add_out, mux_out, mult_out_temp;

	memory_layer2_12_8_1_16#(16, 8, 3)		mem_x(clk, data_in, data_out_x, addr_x, wr_en_x);
	layer2_12_8_1_16_W_rom		rom_w(clk, addr_w, data_out_w);
	layer2_12_8_1_16_B_rom		rom_b(clk, addr_b, data_out_b);

	assign mult_out_temp = (output_counter < 9&& output_counter != 0) ? data_out_x * data_out_w : 0;

	always_comb begin

		if (accum_src == 1 || output_counter <= 1) begin
			add_out = 0;
			mux_out = data_out_b;
		end
		else begin
			add_out  = mult_out  + data_out;
			mux_out = add_out;
		end
	end

	always_ff @(posedge clk) begin
		mult_out <= mult_out_temp;
		if (reset == 1) begin
			data_out <= 0;
		end
		else if (enable_accum == 1) begin
			if (output_counter == 9) begin
				if (mux_out > 0)
					data_out <= mux_out;
				else
					data_out <= 0;
			end
			else
				data_out <= mux_out;
		end

	end
endmodule

module layer3_16_12_1_16(clk, reset, s_valid, m_ready, data_in, m_valid, s_ready, data_out);
	parameter T = 16;
	input clk, reset, s_valid, m_ready;
	input signed [15:0]	data_in;
	output logic signed [15:0]	data_out;
	output m_valid, s_ready;

	logic signed[15:0] data_out1 ;
	logic m_valid1 ;
	logic s_ready1 ;
	logic [0:0] out_count;

	mvma_layer3_16_12_1_16#(.rank(0))  mvma_16_12_1(clk, reset, s_valid, m_ready, data_in, m_valid1, s_ready1, data_out1);

	 assign m_valid = (m_valid1 );
	 assign s_ready = (s_ready1 );

	always_ff @ (posedge clk) begin
		if (reset == 1)
			out_count <= 1;
		if (m_valid && m_ready) begin 
			if (out_count != 1 )
				out_count <= out_count + 1;
			else
				out_count <= 1;
		end
	end

	always_comb begin
		if (out_count == 1 ) 
			data_out = data_out1 ;
		else
			data_out = 0;
	end
endmodule

module mvma_layer3_16_12_1_16(clk, reset, s_valid, m_ready, data_in, m_valid, s_ready, data_out);
	input			clk, reset, s_valid, m_ready;
	input signed [15:0]	data_in;
	output signed [15:0]	data_out;
	output			m_valid, s_ready;
	logic [7:0]		addr_w;
	logic [3:0]		addr_x;
	logic [3:0]		addr_b;
	logic			wr_en_x, accum_src, enable_accum;
	logic [4:0]		output_counter;
	parameter rank;

	control_layer3_16_12_1_16#(.rank(rank))			ctrl(clk, reset, s_valid, m_ready, addr_x, wr_en_x, addr_w, accum_src, m_valid, s_ready, enable_accum, addr_b, output_counter);
	datapath_layer3_16_12_1_16		dpth(clk, reset, data_in, addr_x, wr_en_x, addr_w, accum_src, data_out, enable_accum, addr_b, output_counter);
endmodule

module control_layer3_16_12_1_16(clk, reset, s_valid, m_ready, addr_x, wr_en_x, addr_w, accum_src, m_valid, s_ready, accum_en, addr_b, output_counter);
	input			clk, reset, s_valid, m_ready; 
	output logic [7:0]	addr_w;
	output logic [3:0]	addr_x;
	output logic [3:0]	addr_b;
	output logic		wr_en_x, accum_src, m_valid, s_ready, accum_en;

	logic [1:0] d,c;
	logic [15:0] input_buffer;

	logic			computing, temp;
	logic [4:0]		input_counter;
	output logic [4:0]	output_counter;
	logic [4:0]  count;
	logic [4:0] block;
	parameter T=16, M=16, N=12, P=1, rank;

	always_comb begin
		if( (s_valid == 1) && (s_ready == 1) && (input_counter < 12) )
			wr_en_x = 1;
		else
			wr_en_x = 0;

		if ((reset == 1) || (c ==1))
		    d = 1;
		else
		    d = c + 1;
	end

	always_ff @(posedge clk) begin
		if(reset ==1) begin
			s_ready <= 1;
			addr_x <= 0;
			addr_w <= rank*(12);
			addr_b <= rank;
			accum_src <= 1;
			computing <= 0;
			input_counter <= 0;
			output_counter <= 0;
			accum_en <= 1;
			m_valid <= 0;
			block <= rank;
			count <= 1;
			c <= 0;
			temp <= 1;
			input_buffer <= 0;
		end


		else if (computing == 0) begin
			c <= 0;
			if (c == P)
				 output_counter <= 0;
			if ((input_buffer % (M/P) == 0) || (input_buffer == 0)) begin
				if (s_valid == 1) begin
					if (input_counter < 12) begin
						if (addr_x == 11)
							addr_x <= 0;
					else
						addr_x <= addr_x + 1;
					input_counter <= input_counter + 1;
					end
					if (input_counter == 11) begin
						input_counter <= 0;
						s_ready <= 0;
						computing <= 1;
						temp <= 1;
					end
				end
			end
			else begin 
				 input_counter <= 0;
				 computing <= 1;
				 temp <= 1;
			end
		end


		else if (computing == 1) begin

			if (temp == 1) begin
				 input_buffer <= input_buffer + 1;
				 temp <= 0;
			end

			if ((m_valid == 1) && (m_ready == 1))
				 c <= d;

			if (output_counter < 14)
				output_counter <= output_counter + 1;

			if ((m_valid == 1) && (m_ready == 1) && (d == P))
				accum_src <= 1;
			else if (output_counter == 0)
				accum_src <= 0;

			if (count > N) begin
				 count <= 1;
				 block <= block + P;
			end

			if ( block > M-1) begin
				 block <= rank;
				 addr_w <= rank*(N);
				 count <= 1;
			end
			if (output_counter < 12) begin

				addr_w <= block*(N) + count;
				count <= count + 1;

				if (addr_w == (N*(M + rank - P + 1)) - 1)
					addr_w <= rank;

				if (addr_x == 11)
					addr_x <= 0;
				else
					addr_x <= addr_x + 1;
			end

			if (output_counter == 13) begin
				if (addr_b == (M*N)-(P-1-rank))
					addr_b <= rank;
				else
					if (block <= M-1) begin
						addr_b <= addr_b + P;
						addr_w <= block*N;
				end
					else
						addr_b <= rank;
			end

			if (output_counter == 13)
				accum_en <= 0;

			if ((m_valid == 1) && (m_ready == 1) && (d == P))
				m_valid <= 0;
			else if (output_counter == 13)
				m_valid <= 1;

			if ((m_valid == 1) && (m_ready == 1) && (d == P)) begin
				computing <= 0;
				if (input_buffer % (M/P) == 0)
					s_ready <= 1;
				else 
					s_ready <= 0;
			end

		end
		if  (c == P)  begin
			 accum_en <= 1;
		end

	end
endmodule

module memory_layer3_16_12_1_16(clk, data_in, data_out, addr, wr_en);
	parameter WIDTH = 16, SIZE = 64, LOGSIZE = 6;
	input [WIDTH-1:0]		data_in;
	output logic [WIDTH-1:0]	data_out;
	input [LOGSIZE-1:0]		addr;
	input				clk, wr_en;
	logic [SIZE-1:0][WIDTH-1:0]	mem;
	always_ff @(posedge clk) begin
		data_out <= mem[addr];
		if (wr_en)
			mem[addr] <= data_in;
	end
endmodule

module layer3_16_12_1_16_W_rom(clk, addr, z);
   input clk;
   input [7:0] addr;
   output logic signed [15:0] z;
   always_ff @(posedge clk) begin
      case(addr)
        0: z <= -16'd109;
        1: z <= 16'd124;
        2: z <= 16'd67;
        3: z <= -16'd2;
        4: z <= -16'd41;
        5: z <= 16'd92;
        6: z <= 16'd78;
        7: z <= 16'd78;
        8: z <= 16'd55;
        9: z <= 16'd104;
        10: z <= -16'd3;
        11: z <= 16'd120;
        12: z <= 16'd24;
        13: z <= 16'd8;
        14: z <= -16'd87;
        15: z <= 16'd106;
        16: z <= -16'd2;
        17: z <= -16'd96;
        18: z <= -16'd13;
        19: z <= 16'd35;
        20: z <= 16'd56;
        21: z <= -16'd13;
        22: z <= -16'd108;
        23: z <= -16'd57;
        24: z <= -16'd72;
        25: z <= 16'd74;
        26: z <= -16'd124;
        27: z <= -16'd70;
        28: z <= 16'd39;
        29: z <= -16'd47;
        30: z <= -16'd98;
        31: z <= 16'd58;
        32: z <= -16'd51;
        33: z <= 16'd97;
        34: z <= -16'd72;
        35: z <= 16'd36;
        36: z <= 16'd61;
        37: z <= -16'd121;
        38: z <= -16'd14;
        39: z <= -16'd12;
        40: z <= 16'd111;
        41: z <= 16'd112;
        42: z <= -16'd20;
        43: z <= 16'd7;
        44: z <= -16'd8;
        45: z <= 16'd22;
        46: z <= -16'd14;
        47: z <= 16'd118;
        48: z <= 16'd54;
        49: z <= 16'd101;
        50: z <= 16'd25;
        51: z <= -16'd18;
        52: z <= -16'd39;
        53: z <= 16'd46;
        54: z <= 16'd54;
        55: z <= 16'd17;
        56: z <= -16'd8;
        57: z <= 16'd58;
        58: z <= 16'd75;
        59: z <= -16'd97;
        60: z <= -16'd116;
        61: z <= 16'd105;
        62: z <= 16'd89;
        63: z <= -16'd39;
        64: z <= 16'd74;
        65: z <= -16'd111;
        66: z <= 16'd126;
        67: z <= 16'd8;
        68: z <= -16'd104;
        69: z <= -16'd16;
        70: z <= 16'd124;
        71: z <= -16'd121;
        72: z <= -16'd32;
        73: z <= -16'd23;
        74: z <= 16'd15;
        75: z <= 16'd88;
        76: z <= 16'd127;
        77: z <= -16'd127;
        78: z <= 16'd78;
        79: z <= 16'd53;
        80: z <= 16'd102;
        81: z <= -16'd24;
        82: z <= -16'd93;
        83: z <= -16'd65;
        84: z <= -16'd106;
        85: z <= 16'd89;
        86: z <= 16'd81;
        87: z <= 16'd14;
        88: z <= 16'd20;
        89: z <= 16'd28;
        90: z <= 16'd45;
        91: z <= 16'd32;
        92: z <= 16'd6;
        93: z <= 16'd6;
        94: z <= 16'd121;
        95: z <= -16'd48;
        96: z <= 16'd23;
        97: z <= 16'd119;
        98: z <= 16'd88;
        99: z <= 16'd48;
        100: z <= -16'd24;
        101: z <= 16'd85;
        102: z <= 16'd55;
        103: z <= 16'd72;
        104: z <= -16'd66;
        105: z <= -16'd58;
        106: z <= 16'd33;
        107: z <= -16'd67;
        108: z <= -16'd57;
        109: z <= -16'd17;
        110: z <= 16'd114;
        111: z <= -16'd82;
        112: z <= 16'd87;
        113: z <= -16'd107;
        114: z <= -16'd19;
        115: z <= 16'd109;
        116: z <= 16'd111;
        117: z <= -16'd66;
        118: z <= -16'd5;
        119: z <= 16'd3;
        120: z <= 16'd91;
        121: z <= -16'd88;
        122: z <= -16'd93;
        123: z <= -16'd31;
        124: z <= 16'd46;
        125: z <= -16'd100;
        126: z <= 16'd49;
        127: z <= -16'd58;
        128: z <= -16'd108;
        129: z <= 16'd10;
        130: z <= 16'd118;
        131: z <= -16'd4;
        132: z <= -16'd33;
        133: z <= 16'd45;
        134: z <= -16'd60;
        135: z <= 16'd29;
        136: z <= 16'd116;
        137: z <= 16'd101;
        138: z <= 16'd90;
        139: z <= -16'd69;
        140: z <= -16'd43;
        141: z <= 16'd76;
        142: z <= -16'd23;
        143: z <= -16'd84;
        144: z <= 16'd97;
        145: z <= 16'd87;
        146: z <= -16'd102;
        147: z <= 16'd80;
        148: z <= -16'd107;
        149: z <= 16'd21;
        150: z <= -16'd45;
        151: z <= 16'd112;
        152: z <= 16'd62;
        153: z <= -16'd10;
        154: z <= -16'd47;
        155: z <= -16'd20;
        156: z <= 16'd19;
        157: z <= -16'd125;
        158: z <= 16'd50;
        159: z <= 16'd39;
        160: z <= 16'd13;
        161: z <= 16'd40;
        162: z <= -16'd93;
        163: z <= 16'd108;
        164: z <= -16'd42;
        165: z <= -16'd25;
        166: z <= 16'd9;
        167: z <= -16'd54;
        168: z <= -16'd51;
        169: z <= -16'd29;
        170: z <= 16'd5;
        171: z <= 16'd34;
        172: z <= -16'd81;
        173: z <= 16'd111;
        174: z <= 16'd78;
        175: z <= -16'd112;
        176: z <= 16'd70;
        177: z <= 16'd104;
        178: z <= 16'd97;
        179: z <= 16'd91;
        180: z <= -16'd2;
        181: z <= -16'd76;
        182: z <= 16'd76;
        183: z <= -16'd68;
        184: z <= 16'd43;
        185: z <= -16'd99;
        186: z <= 16'd40;
        187: z <= -16'd66;
        188: z <= -16'd96;
        189: z <= -16'd37;
        190: z <= 16'd101;
        191: z <= 16'd45;
      endcase
   end
endmodule

module layer3_16_12_1_16_B_rom(clk, addr, z);
   input clk;
   input [3:0] addr;
   output logic signed [15:0] z;
   always_ff @(posedge clk) begin
      case(addr)
        0: z <= -16'd125;
        1: z <= -16'd120;
        2: z <= 16'd25;
        3: z <= -16'd39;
        4: z <= -16'd17;
        5: z <= -16'd94;
        6: z <= 16'd35;
        7: z <= 16'd60;
        8: z <= 16'd5;
        9: z <= -16'd87;
        10: z <= -16'd34;
        11: z <= 16'd52;
        12: z <= -16'd104;
        13: z <= -16'd83;
        14: z <= 16'd69;
        15: z <= 16'd94;
      endcase
   end
endmodule

module datapath_layer3_16_12_1_16(clk, reset, data_in, addr_x, wr_en_x, addr_w, accum_src, data_out, enable_accum, addr_b, output_counter);
	input				clk, reset, wr_en_x, accum_src, enable_accum;
	input signed [15:0]		data_in;
	input [7:0]			addr_w;
	input [3:0]			addr_x;
	input [3:0]			addr_b;
	input [4:0]			output_counter;

	output logic signed [15:0]	data_out;
	logic signed [15:0]		data_out_x, data_out_w, data_out_b;
	logic signed [15:0]		mult_out, add_out, mux_out, mult_out_temp;

	memory_layer3_16_12_1_16#(16, 12, 4)		mem_x(clk, data_in, data_out_x, addr_x, wr_en_x);
	layer3_16_12_1_16_W_rom		rom_w(clk, addr_w, data_out_w);
	layer3_16_12_1_16_B_rom		rom_b(clk, addr_b, data_out_b);

	assign mult_out_temp = (output_counter < 13&& output_counter != 0) ? data_out_x * data_out_w : 0;

	always_comb begin

		if (accum_src == 1 || output_counter <= 1) begin
			add_out = 0;
			mux_out = data_out_b;
		end
		else begin
			add_out  = mult_out  + data_out;
			mux_out = add_out;
		end
	end

	always_ff @(posedge clk) begin
		mult_out <= mult_out_temp;
		if (reset == 1) begin
			data_out <= 0;
		end
		else if (enable_accum == 1) begin
			if (output_counter == 13) begin
				if (mux_out > 0)
					data_out <= mux_out;
				else
					data_out <= 0;
			end
			else
				data_out <= mux_out;
		end

	end
endmodule

