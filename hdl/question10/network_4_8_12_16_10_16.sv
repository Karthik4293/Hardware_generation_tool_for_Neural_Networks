module network_4_8_12_16_10_16(clk , reset, s_valid, m_ready, data_in, m_valid, s_ready, data_out);
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
        0: z <= -16'd24;
        1: z <= -16'd9;
        2: z <= -16'd116;
        3: z <= 16'd6;
        4: z <= 16'd47;
        5: z <= 16'd127;
        6: z <= 16'd41;
        7: z <= -16'd33;
        8: z <= 16'd40;
        9: z <= 16'd52;
        10: z <= 16'd57;
        11: z <= -16'd121;
        12: z <= 16'd99;
        13: z <= 16'd61;
        14: z <= 16'd83;
        15: z <= 16'd68;
        16: z <= 16'd27;
        17: z <= 16'd101;
        18: z <= 16'd19;
        19: z <= 16'd18;
        20: z <= -16'd31;
        21: z <= -16'd28;
        22: z <= -16'd1;
        23: z <= 16'd16;
        24: z <= -16'd13;
        25: z <= 16'd47;
        26: z <= -16'd65;
        27: z <= 16'd85;
        28: z <= -16'd116;
        29: z <= -16'd77;
        30: z <= 16'd72;
        31: z <= -16'd12;
      endcase
   end
endmodule

module layer1_8_4_1_16_B_rom(clk, addr, z);
   input clk;
   input [2:0] addr;
   output logic signed [15:0] z;
   always_ff @(posedge clk) begin
      case(addr)
        0: z <= 16'd42;
        1: z <= 16'd84;
        2: z <= 16'd122;
        3: z <= -16'd38;
        4: z <= 16'd83;
        5: z <= 16'd35;
        6: z <= 16'd57;
        7: z <= -16'd4;
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
        0: z <= -16'd41;
        1: z <= -16'd14;
        2: z <= 16'd3;
        3: z <= -16'd70;
        4: z <= -16'd81;
        5: z <= -16'd41;
        6: z <= 16'd126;
        7: z <= 16'd75;
        8: z <= -16'd68;
        9: z <= 16'd17;
        10: z <= -16'd35;
        11: z <= 16'd30;
        12: z <= 16'd118;
        13: z <= 16'd92;
        14: z <= -16'd82;
        15: z <= -16'd23;
        16: z <= 16'd11;
        17: z <= -16'd19;
        18: z <= -16'd66;
        19: z <= 16'd23;
        20: z <= 16'd32;
        21: z <= -16'd122;
        22: z <= -16'd117;
        23: z <= -16'd53;
        24: z <= 16'd90;
        25: z <= -16'd123;
        26: z <= 16'd37;
        27: z <= 16'd45;
        28: z <= 16'd40;
        29: z <= -16'd34;
        30: z <= -16'd87;
        31: z <= 16'd127;
        32: z <= 16'd80;
        33: z <= 16'd45;
        34: z <= -16'd70;
        35: z <= 16'd127;
        36: z <= -16'd124;
        37: z <= -16'd72;
        38: z <= 16'd74;
        39: z <= -16'd64;
        40: z <= 16'd74;
        41: z <= -16'd89;
        42: z <= 16'd94;
        43: z <= 16'd64;
        44: z <= -16'd125;
        45: z <= -16'd116;
        46: z <= -16'd87;
        47: z <= 16'd14;
        48: z <= -16'd6;
        49: z <= -16'd25;
        50: z <= -16'd91;
        51: z <= -16'd102;
        52: z <= -16'd19;
        53: z <= -16'd80;
        54: z <= -16'd27;
        55: z <= -16'd57;
        56: z <= -16'd75;
        57: z <= -16'd118;
        58: z <= 16'd116;
        59: z <= 16'd93;
        60: z <= -16'd24;
        61: z <= -16'd98;
        62: z <= 16'd93;
        63: z <= -16'd72;
        64: z <= 16'd75;
        65: z <= -16'd105;
        66: z <= -16'd72;
        67: z <= 16'd79;
        68: z <= -16'd49;
        69: z <= -16'd126;
        70: z <= -16'd113;
        71: z <= -16'd103;
        72: z <= -16'd86;
        73: z <= 16'd110;
        74: z <= 16'd89;
        75: z <= -16'd83;
        76: z <= 16'd122;
        77: z <= -16'd126;
        78: z <= 16'd60;
        79: z <= -16'd12;
        80: z <= -16'd23;
        81: z <= 16'd97;
        82: z <= 16'd15;
        83: z <= 16'd86;
        84: z <= -16'd110;
        85: z <= 16'd116;
        86: z <= -16'd99;
        87: z <= -16'd57;
        88: z <= 16'd127;
        89: z <= -16'd110;
        90: z <= -16'd91;
        91: z <= -16'd25;
        92: z <= -16'd80;
        93: z <= -16'd126;
        94: z <= 16'd32;
        95: z <= 16'd123;
      endcase
   end
endmodule

module layer2_12_8_1_16_B_rom(clk, addr, z);
   input clk;
   input [3:0] addr;
   output logic signed [15:0] z;
   always_ff @(posedge clk) begin
      case(addr)
        0: z <= -16'd103;
        1: z <= 16'd88;
        2: z <= 16'd74;
        3: z <= -16'd24;
        4: z <= 16'd90;
        5: z <= 16'd89;
        6: z <= 16'd2;
        7: z <= -16'd124;
        8: z <= 16'd71;
        9: z <= -16'd37;
        10: z <= -16'd78;
        11: z <= 16'd66;
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
        0: z <= -16'd34;
        1: z <= 16'd110;
        2: z <= -16'd74;
        3: z <= 16'd71;
        4: z <= 16'd79;
        5: z <= 16'd69;
        6: z <= 16'd30;
        7: z <= 16'd97;
        8: z <= 16'd58;
        9: z <= 16'd59;
        10: z <= -16'd87;
        11: z <= 16'd57;
        12: z <= 16'd77;
        13: z <= -16'd50;
        14: z <= -16'd96;
        15: z <= 16'd125;
        16: z <= -16'd48;
        17: z <= 16'd64;
        18: z <= 16'd120;
        19: z <= -16'd23;
        20: z <= 16'd24;
        21: z <= 16'd66;
        22: z <= 16'd81;
        23: z <= -16'd13;
        24: z <= 16'd28;
        25: z <= -16'd45;
        26: z <= -16'd9;
        27: z <= -16'd29;
        28: z <= 16'd47;
        29: z <= 16'd41;
        30: z <= -16'd91;
        31: z <= -16'd115;
        32: z <= 16'd23;
        33: z <= -16'd36;
        34: z <= 16'd84;
        35: z <= -16'd25;
        36: z <= -16'd95;
        37: z <= -16'd14;
        38: z <= -16'd56;
        39: z <= 16'd91;
        40: z <= -16'd82;
        41: z <= -16'd15;
        42: z <= 16'd20;
        43: z <= 16'd123;
        44: z <= 16'd63;
        45: z <= 16'd53;
        46: z <= 16'd121;
        47: z <= -16'd113;
        48: z <= -16'd11;
        49: z <= 16'd113;
        50: z <= -16'd8;
        51: z <= -16'd114;
        52: z <= 16'd52;
        53: z <= -16'd54;
        54: z <= 16'd1;
        55: z <= -16'd48;
        56: z <= 16'd29;
        57: z <= 16'd120;
        58: z <= 16'd51;
        59: z <= -16'd52;
        60: z <= 16'd34;
        61: z <= 16'd89;
        62: z <= -16'd39;
        63: z <= -16'd71;
        64: z <= -16'd75;
        65: z <= -16'd82;
        66: z <= 16'd32;
        67: z <= -16'd42;
        68: z <= 16'd32;
        69: z <= 16'd105;
        70: z <= -16'd78;
        71: z <= 16'd78;
        72: z <= -16'd38;
        73: z <= 16'd70;
        74: z <= 16'd74;
        75: z <= -16'd102;
        76: z <= -16'd5;
        77: z <= 16'd67;
        78: z <= -16'd87;
        79: z <= 16'd113;
        80: z <= 16'd52;
        81: z <= 16'd34;
        82: z <= 16'd127;
        83: z <= -16'd24;
        84: z <= 16'd108;
        85: z <= 16'd0;
        86: z <= 16'd56;
        87: z <= 16'd9;
        88: z <= -16'd8;
        89: z <= -16'd20;
        90: z <= 16'd86;
        91: z <= -16'd102;
        92: z <= -16'd59;
        93: z <= -16'd81;
        94: z <= -16'd44;
        95: z <= -16'd6;
        96: z <= -16'd35;
        97: z <= 16'd116;
        98: z <= 16'd80;
        99: z <= 16'd126;
        100: z <= 16'd93;
        101: z <= -16'd126;
        102: z <= 16'd76;
        103: z <= -16'd72;
        104: z <= 16'd73;
        105: z <= 16'd22;
        106: z <= -16'd46;
        107: z <= -16'd60;
        108: z <= -16'd39;
        109: z <= -16'd5;
        110: z <= -16'd75;
        111: z <= -16'd114;
        112: z <= -16'd99;
        113: z <= -16'd76;
        114: z <= -16'd10;
        115: z <= -16'd119;
        116: z <= 16'd52;
        117: z <= -16'd81;
        118: z <= 16'd19;
        119: z <= -16'd83;
        120: z <= 16'd27;
        121: z <= -16'd23;
        122: z <= -16'd57;
        123: z <= 16'd96;
        124: z <= 16'd24;
        125: z <= 16'd27;
        126: z <= -16'd38;
        127: z <= 16'd118;
        128: z <= 16'd16;
        129: z <= -16'd86;
        130: z <= 16'd116;
        131: z <= -16'd19;
        132: z <= -16'd83;
        133: z <= 16'd64;
        134: z <= 16'd37;
        135: z <= 16'd118;
        136: z <= -16'd41;
        137: z <= 16'd119;
        138: z <= -16'd70;
        139: z <= 16'd48;
        140: z <= -16'd13;
        141: z <= -16'd16;
        142: z <= 16'd62;
        143: z <= 16'd16;
        144: z <= 16'd36;
        145: z <= -16'd75;
        146: z <= 16'd26;
        147: z <= -16'd39;
        148: z <= -16'd28;
        149: z <= -16'd83;
        150: z <= 16'd6;
        151: z <= 16'd127;
        152: z <= 16'd22;
        153: z <= 16'd77;
        154: z <= 16'd95;
        155: z <= -16'd82;
        156: z <= -16'd23;
        157: z <= -16'd71;
        158: z <= -16'd92;
        159: z <= 16'd121;
        160: z <= -16'd29;
        161: z <= -16'd104;
        162: z <= -16'd26;
        163: z <= 16'd16;
        164: z <= 16'd89;
        165: z <= -16'd116;
        166: z <= 16'd6;
        167: z <= -16'd80;
        168: z <= -16'd125;
        169: z <= 16'd65;
        170: z <= 16'd96;
        171: z <= -16'd10;
        172: z <= -16'd79;
        173: z <= 16'd31;
        174: z <= -16'd121;
        175: z <= 16'd85;
        176: z <= 16'd84;
        177: z <= 16'd33;
        178: z <= -16'd82;
        179: z <= -16'd72;
        180: z <= 16'd78;
        181: z <= 16'd52;
        182: z <= -16'd73;
        183: z <= -16'd28;
        184: z <= 16'd2;
        185: z <= -16'd106;
        186: z <= 16'd18;
        187: z <= 16'd107;
        188: z <= -16'd49;
        189: z <= 16'd55;
        190: z <= 16'd100;
        191: z <= 16'd50;
      endcase
   end
endmodule

module layer3_16_12_1_16_B_rom(clk, addr, z);
   input clk;
   input [3:0] addr;
   output logic signed [15:0] z;
   always_ff @(posedge clk) begin
      case(addr)
        0: z <= 16'd79;
        1: z <= -16'd54;
        2: z <= -16'd61;
        3: z <= 16'd40;
        4: z <= -16'd42;
        5: z <= 16'd73;
        6: z <= 16'd88;
        7: z <= -16'd38;
        8: z <= 16'd10;
        9: z <= 16'd57;
        10: z <= 16'd80;
        11: z <= 16'd59;
        12: z <= -16'd40;
        13: z <= 16'd87;
        14: z <= 16'd17;
        15: z <= -16'd84;
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

