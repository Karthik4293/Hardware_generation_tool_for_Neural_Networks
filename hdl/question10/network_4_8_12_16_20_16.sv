module network_4_8_12_16_20_16(clk , reset, s_valid, m_ready, data_in, m_valid, s_ready, data_out);
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
        0: z <= 16'd101;
        1: z <= 16'd79;
        2: z <= -16'd93;
        3: z <= -16'd124;
        4: z <= 16'd25;
        5: z <= 16'd12;
        6: z <= 16'd64;
        7: z <= 16'd34;
        8: z <= -16'd74;
        9: z <= 16'd126;
        10: z <= 16'd120;
        11: z <= -16'd46;
        12: z <= -16'd122;
        13: z <= -16'd118;
        14: z <= 16'd47;
        15: z <= -16'd84;
        16: z <= -16'd95;
        17: z <= 16'd77;
        18: z <= -16'd53;
        19: z <= -16'd93;
        20: z <= 16'd114;
        21: z <= -16'd81;
        22: z <= -16'd72;
        23: z <= 16'd64;
        24: z <= 16'd45;
        25: z <= 16'd37;
        26: z <= -16'd115;
        27: z <= -16'd23;
        28: z <= 16'd73;
        29: z <= 16'd73;
        30: z <= -16'd63;
        31: z <= 16'd47;
      endcase
   end
endmodule

module layer1_8_4_1_16_B_rom(clk, addr, z);
   input clk;
   input [2:0] addr;
   output logic signed [15:0] z;
   always_ff @(posedge clk) begin
      case(addr)
        0: z <= 16'd24;
        1: z <= -16'd28;
        2: z <= 16'd51;
        3: z <= -16'd78;
        4: z <= 16'd112;
        5: z <= -16'd12;
        6: z <= 16'd84;
        7: z <= -16'd90;
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
        0: z <= -16'd14;
        1: z <= 16'd76;
        2: z <= -16'd7;
        3: z <= -16'd7;
        4: z <= 16'd87;
        5: z <= -16'd88;
        6: z <= 16'd37;
        7: z <= 16'd120;
        8: z <= 16'd118;
        9: z <= 16'd112;
        10: z <= -16'd101;
        11: z <= 16'd104;
        12: z <= -16'd96;
        13: z <= -16'd45;
        14: z <= 16'd40;
        15: z <= 16'd77;
        16: z <= 16'd120;
        17: z <= 16'd53;
        18: z <= -16'd74;
        19: z <= 16'd66;
        20: z <= -16'd1;
        21: z <= -16'd8;
        22: z <= -16'd15;
        23: z <= -16'd105;
        24: z <= 16'd92;
        25: z <= -16'd92;
        26: z <= -16'd55;
        27: z <= 16'd77;
        28: z <= 16'd24;
        29: z <= -16'd98;
        30: z <= 16'd115;
        31: z <= -16'd117;
        32: z <= 16'd106;
        33: z <= -16'd20;
        34: z <= 16'd4;
        35: z <= 16'd65;
        36: z <= 16'd21;
        37: z <= -16'd87;
        38: z <= 16'd57;
        39: z <= 16'd11;
        40: z <= -16'd103;
        41: z <= 16'd85;
        42: z <= -16'd13;
        43: z <= -16'd71;
        44: z <= -16'd88;
        45: z <= -16'd100;
        46: z <= -16'd122;
        47: z <= -16'd95;
        48: z <= 16'd81;
        49: z <= -16'd67;
        50: z <= 16'd99;
        51: z <= -16'd48;
        52: z <= 16'd53;
        53: z <= -16'd44;
        54: z <= -16'd24;
        55: z <= 16'd17;
        56: z <= -16'd8;
        57: z <= 16'd49;
        58: z <= -16'd34;
        59: z <= -16'd111;
        60: z <= 16'd79;
        61: z <= -16'd46;
        62: z <= -16'd100;
        63: z <= 16'd58;
        64: z <= 16'd62;
        65: z <= 16'd32;
        66: z <= -16'd5;
        67: z <= -16'd45;
        68: z <= 16'd73;
        69: z <= -16'd75;
        70: z <= 16'd94;
        71: z <= 16'd98;
        72: z <= -16'd118;
        73: z <= -16'd46;
        74: z <= -16'd100;
        75: z <= -16'd78;
        76: z <= -16'd18;
        77: z <= -16'd94;
        78: z <= -16'd45;
        79: z <= -16'd65;
        80: z <= -16'd33;
        81: z <= -16'd74;
        82: z <= 16'd16;
        83: z <= -16'd108;
        84: z <= 16'd10;
        85: z <= 16'd120;
        86: z <= 16'd38;
        87: z <= -16'd125;
        88: z <= 16'd41;
        89: z <= -16'd124;
        90: z <= -16'd108;
        91: z <= -16'd7;
        92: z <= -16'd42;
        93: z <= -16'd80;
        94: z <= -16'd77;
        95: z <= -16'd107;
      endcase
   end
endmodule

module layer2_12_8_1_16_B_rom(clk, addr, z);
   input clk;
   input [3:0] addr;
   output logic signed [15:0] z;
   always_ff @(posedge clk) begin
      case(addr)
        0: z <= 16'd80;
        1: z <= 16'd46;
        2: z <= -16'd24;
        3: z <= 16'd25;
        4: z <= 16'd99;
        5: z <= -16'd57;
        6: z <= -16'd5;
        7: z <= 16'd109;
        8: z <= 16'd25;
        9: z <= 16'd23;
        10: z <= -16'd96;
        11: z <= -16'd121;
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
        0: z <= 16'd58;
        1: z <= -16'd13;
        2: z <= -16'd58;
        3: z <= -16'd103;
        4: z <= 16'd42;
        5: z <= 16'd86;
        6: z <= -16'd82;
        7: z <= -16'd76;
        8: z <= 16'd78;
        9: z <= 16'd84;
        10: z <= -16'd73;
        11: z <= -16'd8;
        12: z <= 16'd88;
        13: z <= -16'd53;
        14: z <= 16'd113;
        15: z <= -16'd81;
        16: z <= -16'd5;
        17: z <= -16'd92;
        18: z <= -16'd60;
        19: z <= -16'd53;
        20: z <= 16'd82;
        21: z <= 16'd44;
        22: z <= 16'd100;
        23: z <= 16'd54;
        24: z <= 16'd115;
        25: z <= -16'd32;
        26: z <= 16'd35;
        27: z <= 16'd12;
        28: z <= 16'd119;
        29: z <= 16'd67;
        30: z <= 16'd19;
        31: z <= 16'd49;
        32: z <= -16'd73;
        33: z <= 16'd90;
        34: z <= 16'd75;
        35: z <= 16'd97;
        36: z <= 16'd48;
        37: z <= 16'd121;
        38: z <= -16'd107;
        39: z <= -16'd1;
        40: z <= 16'd77;
        41: z <= -16'd51;
        42: z <= 16'd119;
        43: z <= 16'd37;
        44: z <= 16'd24;
        45: z <= 16'd104;
        46: z <= 16'd84;
        47: z <= -16'd108;
        48: z <= -16'd116;
        49: z <= -16'd104;
        50: z <= -16'd33;
        51: z <= 16'd94;
        52: z <= 16'd69;
        53: z <= -16'd60;
        54: z <= 16'd20;
        55: z <= 16'd56;
        56: z <= 16'd36;
        57: z <= -16'd72;
        58: z <= -16'd59;
        59: z <= 16'd27;
        60: z <= 16'd123;
        61: z <= 16'd88;
        62: z <= -16'd51;
        63: z <= -16'd78;
        64: z <= 16'd50;
        65: z <= -16'd104;
        66: z <= -16'd109;
        67: z <= -16'd29;
        68: z <= -16'd111;
        69: z <= -16'd87;
        70: z <= 16'd98;
        71: z <= 16'd94;
        72: z <= -16'd10;
        73: z <= 16'd89;
        74: z <= 16'd3;
        75: z <= -16'd114;
        76: z <= 16'd65;
        77: z <= -16'd40;
        78: z <= -16'd94;
        79: z <= 16'd77;
        80: z <= -16'd16;
        81: z <= 16'd2;
        82: z <= 16'd43;
        83: z <= -16'd75;
        84: z <= 16'd70;
        85: z <= -16'd64;
        86: z <= 16'd110;
        87: z <= -16'd22;
        88: z <= -16'd8;
        89: z <= -16'd77;
        90: z <= -16'd123;
        91: z <= -16'd13;
        92: z <= -16'd117;
        93: z <= -16'd46;
        94: z <= 16'd38;
        95: z <= 16'd62;
        96: z <= -16'd22;
        97: z <= 16'd57;
        98: z <= -16'd95;
        99: z <= -16'd5;
        100: z <= 16'd98;
        101: z <= -16'd125;
        102: z <= -16'd39;
        103: z <= -16'd40;
        104: z <= 16'd92;
        105: z <= 16'd93;
        106: z <= -16'd25;
        107: z <= 16'd29;
        108: z <= -16'd75;
        109: z <= 16'd9;
        110: z <= -16'd22;
        111: z <= 16'd37;
        112: z <= -16'd117;
        113: z <= -16'd107;
        114: z <= 16'd91;
        115: z <= 16'd81;
        116: z <= -16'd43;
        117: z <= 16'd73;
        118: z <= -16'd69;
        119: z <= 16'd77;
        120: z <= 16'd124;
        121: z <= -16'd63;
        122: z <= -16'd63;
        123: z <= -16'd121;
        124: z <= 16'd19;
        125: z <= 16'd103;
        126: z <= 16'd69;
        127: z <= 16'd126;
        128: z <= 16'd32;
        129: z <= 16'd102;
        130: z <= -16'd7;
        131: z <= 16'd3;
        132: z <= 16'd105;
        133: z <= 16'd83;
        134: z <= 16'd91;
        135: z <= 16'd69;
        136: z <= 16'd48;
        137: z <= -16'd62;
        138: z <= -16'd30;
        139: z <= 16'd101;
        140: z <= 16'd76;
        141: z <= 16'd76;
        142: z <= 16'd10;
        143: z <= 16'd87;
        144: z <= 16'd98;
        145: z <= -16'd27;
        146: z <= 16'd41;
        147: z <= -16'd73;
        148: z <= -16'd82;
        149: z <= 16'd100;
        150: z <= -16'd123;
        151: z <= -16'd86;
        152: z <= -16'd91;
        153: z <= -16'd58;
        154: z <= -16'd78;
        155: z <= 16'd57;
        156: z <= -16'd83;
        157: z <= 16'd119;
        158: z <= 16'd55;
        159: z <= 16'd77;
        160: z <= 16'd94;
        161: z <= -16'd80;
        162: z <= -16'd48;
        163: z <= 16'd71;
        164: z <= -16'd125;
        165: z <= -16'd84;
        166: z <= 16'd13;
        167: z <= 16'd51;
        168: z <= -16'd18;
        169: z <= 16'd111;
        170: z <= 16'd24;
        171: z <= -16'd70;
        172: z <= 16'd60;
        173: z <= -16'd93;
        174: z <= -16'd110;
        175: z <= 16'd30;
        176: z <= 16'd8;
        177: z <= 16'd59;
        178: z <= 16'd85;
        179: z <= 16'd55;
        180: z <= 16'd31;
        181: z <= 16'd90;
        182: z <= 16'd97;
        183: z <= 16'd69;
        184: z <= -16'd96;
        185: z <= -16'd109;
        186: z <= -16'd2;
        187: z <= -16'd51;
        188: z <= -16'd117;
        189: z <= -16'd75;
        190: z <= -16'd101;
        191: z <= 16'd105;
      endcase
   end
endmodule

module layer3_16_12_1_16_B_rom(clk, addr, z);
   input clk;
   input [3:0] addr;
   output logic signed [15:0] z;
   always_ff @(posedge clk) begin
      case(addr)
        0: z <= -16'd27;
        1: z <= -16'd21;
        2: z <= 16'd48;
        3: z <= -16'd23;
        4: z <= 16'd23;
        5: z <= -16'd67;
        6: z <= -16'd100;
        7: z <= -16'd122;
        8: z <= -16'd83;
        9: z <= 16'd53;
        10: z <= -16'd64;
        11: z <= 16'd105;
        12: z <= 16'd88;
        13: z <= -16'd46;
        14: z <= 16'd7;
        15: z <= -16'd32;
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

