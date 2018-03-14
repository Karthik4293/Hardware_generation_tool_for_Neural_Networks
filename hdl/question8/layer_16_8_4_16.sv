module layer_16_8_4_16(clk, reset, s_valid, m_ready, data_in, m_valid, s_ready, data_out);
	parameter T = 16;
	input clk, reset, s_valid, m_ready;
	input signed [15:0]	data_in;
	output logic signed [15:0]	data_out;
	output m_valid, s_ready;

	logic signed[15:0] data_out1, data_out2, data_out3, data_out4 ;
	logic m_valid1, m_valid2, m_valid3, m_valid4 ;
	logic s_ready1, s_ready2, s_ready3, s_ready4 ;
	logic [3:0] out_count;

	mvma#(.rank(0))  mvma_16_8_1(clk, reset, s_valid, m_ready, data_in, m_valid1, s_ready1, data_out1);
	mvma#(.rank(1))  mvma_16_8_2(clk, reset, s_valid, m_ready, data_in, m_valid2, s_ready2, data_out2);
	mvma#(.rank(2))  mvma_16_8_3(clk, reset, s_valid, m_ready, data_in, m_valid3, s_ready3, data_out3);
	mvma#(.rank(3))  mvma_16_8_4(clk, reset, s_valid, m_ready, data_in, m_valid4, s_ready4, data_out4);

	 assign m_valid = (m_valid1 || m_valid2 || m_valid3 || m_valid4 );
	 assign s_ready = (s_ready1 || s_ready2 || s_ready3 || s_ready4 );

	always_ff @ (posedge clk) begin
		if (reset == 1)
			out_count <= 1;
		if (m_valid && m_ready) begin 
			if (out_count != 4 )
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

	logic [4:0] d,c;
	logic [15:0] input_buffer;

	logic			computing, temp;
	logic [3:0]		input_counter;
	output logic [3:0]	output_counter;
	logic [3:0]  count;
	logic [4:0] block;
	parameter T=16, M=16, N=8, P=4, rank = 0;

	always_comb begin
		if( (s_valid == 1) && (s_ready == 1) && (input_counter < 8) )
			wr_en_x = 1;
		else
			wr_en_x = 0;

		if ((reset == 1) || (c ==4))
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

module layer_16_8_4_16_W_rom(clk, addr, z);
   input clk;
   input [6:0] addr;
   output logic signed [15:0] z;
   always_ff @(posedge clk) begin
      case(addr)
        0: z <= -16'd121;
        1: z <= 16'd61;
        2: z <= 16'd55;
        3: z <= -16'd63;
        4: z <= 16'd1;
        5: z <= 16'd119;
        6: z <= 16'd91;
        7: z <= 16'd117;
        8: z <= 16'd125;
        9: z <= 16'd49;
        10: z <= 16'd45;
        11: z <= 16'd6;
        12: z <= -16'd108;
        13: z <= -16'd60;
        14: z <= -16'd42;
        15: z <= -16'd108;
        16: z <= 16'd94;
        17: z <= 16'd49;
        18: z <= 16'd93;
        19: z <= 16'd89;
        20: z <= 16'd77;
        21: z <= -16'd45;
        22: z <= -16'd75;
        23: z <= 16'd70;
        24: z <= 16'd63;
        25: z <= -16'd75;
        26: z <= 16'd29;
        27: z <= -16'd48;
        28: z <= 16'd100;
        29: z <= 16'd124;
        30: z <= 16'd10;
        31: z <= 16'd107;
        32: z <= 16'd57;
        33: z <= -16'd63;
        34: z <= -16'd84;
        35: z <= -16'd70;
        36: z <= -16'd72;
        37: z <= -16'd121;
        38: z <= -16'd80;
        39: z <= -16'd74;
        40: z <= 16'd57;
        41: z <= 16'd93;
        42: z <= 16'd60;
        43: z <= 16'd77;
        44: z <= -16'd95;
        45: z <= -16'd109;
        46: z <= 16'd98;
        47: z <= 16'd127;
        48: z <= 16'd68;
        49: z <= 16'd63;
        50: z <= 16'd88;
        51: z <= 16'd17;
        52: z <= -16'd110;
        53: z <= -16'd115;
        54: z <= -16'd40;
        55: z <= 16'd81;
        56: z <= -16'd62;
        57: z <= 16'd117;
        58: z <= -16'd95;
        59: z <= -16'd90;
        60: z <= 16'd113;
        61: z <= 16'd44;
        62: z <= -16'd110;
        63: z <= 16'd43;
        64: z <= 16'd109;
        65: z <= -16'd66;
        66: z <= 16'd101;
        67: z <= -16'd90;
        68: z <= -16'd58;
        69: z <= -16'd107;
        70: z <= -16'd36;
        71: z <= 16'd127;
        72: z <= 16'd114;
        73: z <= -16'd104;
        74: z <= 16'd76;
        75: z <= -16'd109;
        76: z <= -16'd85;
        77: z <= 16'd46;
        78: z <= -16'd109;
        79: z <= 16'd112;
        80: z <= -16'd18;
        81: z <= 16'd107;
        82: z <= 16'd1;
        83: z <= 16'd0;
        84: z <= 16'd121;
        85: z <= 16'd89;
        86: z <= -16'd46;
        87: z <= -16'd69;
        88: z <= 16'd78;
        89: z <= -16'd13;
        90: z <= -16'd30;
        91: z <= 16'd64;
        92: z <= -16'd97;
        93: z <= -16'd12;
        94: z <= -16'd21;
        95: z <= -16'd115;
        96: z <= 16'd50;
        97: z <= -16'd48;
        98: z <= -16'd77;
        99: z <= 16'd120;
        100: z <= -16'd26;
        101: z <= 16'd15;
        102: z <= 16'd119;
        103: z <= -16'd40;
        104: z <= 16'd39;
        105: z <= 16'd68;
        106: z <= -16'd20;
        107: z <= 16'd83;
        108: z <= -16'd14;
        109: z <= -16'd1;
        110: z <= 16'd67;
        111: z <= 16'd96;
        112: z <= -16'd22;
        113: z <= -16'd60;
        114: z <= -16'd31;
        115: z <= -16'd29;
        116: z <= -16'd98;
        117: z <= 16'd51;
        118: z <= 16'd31;
        119: z <= 16'd108;
        120: z <= -16'd90;
        121: z <= -16'd127;
        122: z <= 16'd44;
        123: z <= -16'd58;
        124: z <= -16'd11;
        125: z <= -16'd105;
        126: z <= -16'd45;
        127: z <= -16'd89;
      endcase
   end
endmodule

module layer_16_8_4_16_B_rom(clk, addr, z);
   input clk;
   input [3:0] addr;
   output logic signed [15:0] z;
   always_ff @(posedge clk) begin
      case(addr)
        0: z <= -16'd24;
        1: z <= 16'd6;
        2: z <= -16'd96;
        3: z <= 16'd78;
        4: z <= -16'd107;
        5: z <= -16'd105;
        6: z <= -16'd90;
        7: z <= 16'd60;
        8: z <= 16'd91;
        9: z <= 16'd18;
        10: z <= 16'd15;
        11: z <= -16'd50;
        12: z <= -16'd111;
        13: z <= -16'd46;
        14: z <= -16'd82;
        15: z <= -16'd4;
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
	layer_16_8_4_16_W_rom		rom_w(clk, addr_w, data_out_w);
	layer_16_8_4_16_B_rom		rom_b(clk, addr_b, data_out_b);

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

