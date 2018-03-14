module layer_16_8_8_16(clk, reset, s_valid, m_ready, data_in, m_valid, s_ready, data_out);
	parameter T = 16;
	input clk, reset, s_valid, m_ready;
	input signed [15:0]	data_in;
	output logic signed [15:0]	data_out;
	output m_valid, s_ready;

	logic signed[15:0] data_out1, data_out2, data_out3, data_out4, data_out5, data_out6, data_out7, data_out8 ;
	logic m_valid1, m_valid2, m_valid3, m_valid4, m_valid5, m_valid6, m_valid7, m_valid8 ;
	logic s_ready1, s_ready2, s_ready3, s_ready4, s_ready5, s_ready6, s_ready7, s_ready8 ;
	logic [7:0] out_count;

	mvma#(.rank(0))  mvma_16_8_1(clk, reset, s_valid, m_ready, data_in, m_valid1, s_ready1, data_out1);
	mvma#(.rank(1))  mvma_16_8_2(clk, reset, s_valid, m_ready, data_in, m_valid2, s_ready2, data_out2);
	mvma#(.rank(2))  mvma_16_8_3(clk, reset, s_valid, m_ready, data_in, m_valid3, s_ready3, data_out3);
	mvma#(.rank(3))  mvma_16_8_4(clk, reset, s_valid, m_ready, data_in, m_valid4, s_ready4, data_out4);
	mvma#(.rank(4))  mvma_16_8_5(clk, reset, s_valid, m_ready, data_in, m_valid5, s_ready5, data_out5);
	mvma#(.rank(5))  mvma_16_8_6(clk, reset, s_valid, m_ready, data_in, m_valid6, s_ready6, data_out6);
	mvma#(.rank(6))  mvma_16_8_7(clk, reset, s_valid, m_ready, data_in, m_valid7, s_ready7, data_out7);
	mvma#(.rank(7))  mvma_16_8_8(clk, reset, s_valid, m_ready, data_in, m_valid8, s_ready8, data_out8);

	 assign m_valid = (m_valid1 || m_valid2 || m_valid3 || m_valid4 || m_valid5 || m_valid6 || m_valid7 || m_valid8 );
	 assign s_ready = (s_ready1 || s_ready2 || s_ready3 || s_ready4 || s_ready5 || s_ready6 || s_ready7 || s_ready8 );

	always_ff @ (posedge clk) begin
		if (reset == 1)
			out_count <= 1;
		if (m_valid && m_ready) begin 
			if (out_count != 8 )
				out_count <= out_count + 1;
			else
				out_count <= 1;
		end
	end

	always_comb begin
		if (out_count == 1 ) 
			data_out = data_out1 ;
		else if (out_count == 2 ) 
			data_out = data_out2 ;
		else if (out_count == 3 ) 
			data_out = data_out3 ;
		else if (out_count == 4 ) 
			data_out = data_out4 ;
		else if (out_count == 5 ) 
			data_out = data_out5 ;
		else if (out_count == 6 ) 
			data_out = data_out6 ;
		else if (out_count == 7 ) 
			data_out = data_out7 ;
		else if (out_count == 8 ) 
			data_out = data_out8 ;
		else
			data_out = 0;
	end
endmodule

module mvma(clk, reset, s_valid, m_ready, data_in, m_valid, s_ready, data_out);
	input			clk, reset, s_valid, m_ready;
	input signed [15:0]	data_in;
	output signed [15:0]	data_out;
	output			m_valid, s_ready;
	logic [6:0]		addr_w;
	logic [2:0]		addr_x;
	logic [3:0]		addr_b;
	logic			wr_en_x, accum_src, enable_accum;
	logic [3:0]		output_counter;
	parameter rank = 0;

	control#(.rank(rank))			ctrl(clk, reset, s_valid, m_ready, addr_x, wr_en_x, addr_w, accum_src, m_valid, s_ready, enable_accum, addr_b, output_counter);
	datapath		dpth(clk, reset, data_in, addr_x, wr_en_x, addr_w, accum_src, data_out, enable_accum, addr_b, output_counter);
endmodule

module control(clk, reset, s_valid, m_ready, addr_x, wr_en_x, addr_w, accum_src, m_valid, s_ready, accum_en, addr_b, output_counter);
	input			clk, reset, s_valid, m_ready; 
	output logic [6:0]	addr_w;
	output logic [2:0]	addr_x;
	output logic [3:0]	addr_b;
	output logic		wr_en_x, accum_src, m_valid, s_ready, accum_en;

	logic [8:0] d,c;
	logic [15:0] input_buffer;

	logic			computing, temp;
	logic [3:0]		input_counter;
	output logic [3:0]	output_counter;
	logic [3:0]  count;
	logic [4:0] block;
	parameter T=16, M=16, N=8, P=8, rank = 0;

	always_comb begin
		if( (s_valid == 1) && (s_ready == 1) && (input_counter < 8) )
			wr_en_x = 1;
		else
			wr_en_x = 0;

		if ((reset == 1) || (c ==8))
		    d = 1;
		else
		    d = c + 1;
	end

	always_ff @(posedge clk) begin
		if(reset ==1) begin
			s_ready <= 1;
			addr_x <= 0;
			addr_w <= rank*($unsigned(8));
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
			if ((input_buffer % ($unsigned(M)/$unsigned(P)) == 0) || (input_buffer == 0)) begin
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

			if ( block > $unsigned(M) - 1) begin
				 block <= rank;
				 addr_w <= rank* $unsigned(N);
				 count <= 1;
			end
			if (output_counter < 8) begin

				addr_w <= block*(N) + count;
				count <= count + 1;

				if (addr_w == $unsigned((N*(M + rank - P + 1)) - 1))
					addr_w <= rank;

				if (addr_x == 7)
					addr_x <= 0;
				else
					addr_x <= addr_x + 1;
			end

			if (output_counter == 9) begin
					if (block <= $unsigned(M-1) ) begin
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
				if (input_buffer % $unsigned(M/P) == 0)
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

module memory(clk, data_in, data_out, addr, wr_en);
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

module layer_16_8_8_16_W_rom(clk, addr, z);
   input clk;
   input [6:0] addr;
   output logic signed [15:0] z;
   always_ff @(posedge clk) begin
      case(addr)
        0: z <= 16'd42;
        1: z <= -16'd67;
        2: z <= -16'd51;
        3: z <= -16'd77;
        4: z <= 16'd78;
        5: z <= -16'd40;
        6: z <= 16'd119;
        7: z <= 16'd43;
        8: z <= 16'd67;
        9: z <= -16'd39;
        10: z <= -16'd35;
        11: z <= 16'd71;
        12: z <= -16'd85;
        13: z <= 16'd78;
        14: z <= -16'd29;
        15: z <= -16'd101;
        16: z <= -16'd49;
        17: z <= -16'd58;
        18: z <= -16'd76;
        19: z <= -16'd51;
        20: z <= -16'd123;
        21: z <= 16'd85;
        22: z <= -16'd76;
        23: z <= 16'd59;
        24: z <= 16'd66;
        25: z <= 16'd54;
        26: z <= -16'd117;
        27: z <= 16'd127;
        28: z <= 16'd98;
        29: z <= 16'd37;
        30: z <= 16'd126;
        31: z <= 16'd12;
        32: z <= 16'd98;
        33: z <= -16'd53;
        34: z <= 16'd63;
        35: z <= 16'd49;
        36: z <= 16'd35;
        37: z <= 16'd55;
        38: z <= -16'd36;
        39: z <= -16'd25;
        40: z <= -16'd112;
        41: z <= 16'd57;
        42: z <= -16'd82;
        43: z <= -16'd69;
        44: z <= 16'd7;
        45: z <= 16'd18;
        46: z <= -16'd42;
        47: z <= 16'd87;
        48: z <= 16'd88;
        49: z <= 16'd11;
        50: z <= -16'd92;
        51: z <= 16'd94;
        52: z <= -16'd32;
        53: z <= -16'd39;
        54: z <= 16'd25;
        55: z <= -16'd94;
        56: z <= -16'd113;
        57: z <= 16'd36;
        58: z <= -16'd95;
        59: z <= 16'd113;
        60: z <= -16'd54;
        61: z <= -16'd97;
        62: z <= -16'd3;
        63: z <= -16'd84;
        64: z <= -16'd22;
        65: z <= -16'd67;
        66: z <= 16'd93;
        67: z <= -16'd114;
        68: z <= 16'd116;
        69: z <= -16'd71;
        70: z <= -16'd11;
        71: z <= -16'd124;
        72: z <= 16'd114;
        73: z <= 16'd35;
        74: z <= -16'd64;
        75: z <= -16'd6;
        76: z <= -16'd75;
        77: z <= 16'd22;
        78: z <= -16'd47;
        79: z <= -16'd114;
        80: z <= -16'd95;
        81: z <= -16'd11;
        82: z <= 16'd108;
        83: z <= 16'd1;
        84: z <= 16'd78;
        85: z <= 16'd5;
        86: z <= 16'd36;
        87: z <= 16'd94;
        88: z <= -16'd86;
        89: z <= 16'd69;
        90: z <= 16'd79;
        91: z <= -16'd12;
        92: z <= 16'd101;
        93: z <= -16'd51;
        94: z <= 16'd32;
        95: z <= -16'd49;
        96: z <= 16'd10;
        97: z <= -16'd2;
        98: z <= -16'd35;
        99: z <= -16'd2;
        100: z <= 16'd55;
        101: z <= 16'd82;
        102: z <= 16'd2;
        103: z <= 16'd42;
        104: z <= -16'd10;
        105: z <= 16'd66;
        106: z <= -16'd92;
        107: z <= 16'd43;
        108: z <= -16'd39;
        109: z <= -16'd11;
        110: z <= 16'd57;
        111: z <= -16'd6;
        112: z <= 16'd106;
        113: z <= 16'd37;
        114: z <= 16'd124;
        115: z <= 16'd57;
        116: z <= -16'd85;
        117: z <= 16'd32;
        118: z <= 16'd23;
        119: z <= -16'd43;
        120: z <= -16'd27;
        121: z <= -16'd26;
        122: z <= 16'd73;
        123: z <= -16'd54;
        124: z <= 16'd51;
        125: z <= -16'd23;
        126: z <= 16'd26;
        127: z <= -16'd67;
      endcase
   end
endmodule

module layer_16_8_8_16_B_rom(clk, addr, z);
   input clk;
   input [3:0] addr;
   output logic signed [15:0] z;
   always_ff @(posedge clk) begin
      case(addr)
        0: z <= 16'd103;
        1: z <= 16'd119;
        2: z <= 16'd59;
        3: z <= 16'd31;
        4: z <= 16'd74;
        5: z <= -16'd66;
        6: z <= -16'd55;
        7: z <= -16'd64;
        8: z <= -16'd128;
        9: z <= -16'd19;
        10: z <= 16'd107;
        11: z <= -16'd39;
        12: z <= 16'd98;
        13: z <= 16'd37;
        14: z <= 16'd84;
        15: z <= 16'd76;
      endcase
   end
endmodule

module datapath(clk, reset, data_in, addr_x, wr_en_x, addr_w, accum_src, data_out, enable_accum, addr_b, output_counter);
	input				clk, reset, wr_en_x, accum_src, enable_accum;
	input signed [15:0]		data_in;
	input [6:0]			addr_w;
	input [2:0]			addr_x;
	input [3:0]			addr_b;
	input [3:0]			output_counter;

	output logic signed [15:0]	data_out;
	logic signed [15:0]		data_out_x, data_out_w, data_out_b;
	logic signed [15:0]		mult_out, add_out, mux_out, mult_out_temp;

	memory #(16, 8, 3)		mem_x(clk, data_in, data_out_x, addr_x, wr_en_x);
	layer_16_8_8_16_W_rom		rom_w(clk, addr_w, data_out_w);
	layer_16_8_8_16_B_rom		rom_b(clk, addr_b, data_out_b);

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

