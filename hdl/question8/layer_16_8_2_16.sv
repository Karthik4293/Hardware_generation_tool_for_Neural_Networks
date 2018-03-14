module layer_16_8_2_16(clk, reset, s_valid, m_ready, data_in, m_valid, s_ready, data_out);
	parameter T = 16;
	input clk, reset, s_valid, m_ready;
	input signed [15:0]	data_in;
	output logic signed [15:0]	data_out;
	output m_valid, s_ready;

	logic signed[15:0] data_out1, data_out2 ;
	logic m_valid1, m_valid2 ;
	logic s_ready1, s_ready2 ;
	logic [1:0] out_count;

	mvma#(.rank(0))  mvma_16_8_1(clk, reset, s_valid, m_ready, data_in, m_valid1, s_ready1, data_out1);
	mvma#(.rank(1))  mvma_16_8_2(clk, reset, s_valid, m_ready, data_in, m_valid2, s_ready2, data_out2);

	 assign m_valid = (m_valid1 || m_valid2 );
	 assign s_ready = (s_ready1 || s_ready2 );

	always_ff @ (posedge clk) begin
		if (reset == 1)
			out_count <= 1;
		if (m_valid && m_ready) begin 
			if (out_count != 2 )
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

	logic [2:0] d,c;
	logic [15:0] input_buffer;

	logic			computing, temp;
	logic [3:0]		input_counter;
	output logic [3:0]	output_counter;
	logic [3:0]  count;
	logic [4:0] block;
	parameter T=16, M=16, N=8, P=2, rank = 0;

	always_comb begin
		if( (s_valid == 1) && (s_ready == 1) && (input_counter < 8) )
			wr_en_x = 1;
		else
			wr_en_x = 0;

		if ((reset == 1) || (c ==2))
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

module layer_16_8_2_16_W_rom(clk, addr, z);
   input clk;
   input [6:0] addr;
   output logic signed [15:0] z;
   always_ff @(posedge clk) begin
      case(addr)
        0: z <= -16'd80;
        1: z <= -16'd127;
        2: z <= 16'd39;
        3: z <= 16'd86;
        4: z <= 16'd85;
        5: z <= -16'd98;
        6: z <= -16'd55;
        7: z <= 16'd29;
        8: z <= -16'd4;
        9: z <= -16'd6;
        10: z <= 16'd12;
        11: z <= -16'd14;
        12: z <= -16'd56;
        13: z <= 16'd21;
        14: z <= -16'd78;
        15: z <= -16'd108;
        16: z <= -16'd25;
        17: z <= -16'd48;
        18: z <= 16'd84;
        19: z <= -16'd83;
        20: z <= -16'd48;
        21: z <= 16'd10;
        22: z <= 16'd24;
        23: z <= -16'd104;
        24: z <= -16'd125;
        25: z <= 16'd28;
        26: z <= -16'd50;
        27: z <= 16'd55;
        28: z <= 16'd56;
        29: z <= 16'd116;
        30: z <= 16'd99;
        31: z <= 16'd104;
        32: z <= 16'd117;
        33: z <= 16'd10;
        34: z <= 16'd62;
        35: z <= 16'd74;
        36: z <= 16'd40;
        37: z <= -16'd121;
        38: z <= -16'd24;
        39: z <= -16'd92;
        40: z <= 16'd1;
        41: z <= 16'd116;
        42: z <= 16'd23;
        43: z <= 16'd74;
        44: z <= 16'd10;
        45: z <= 16'd73;
        46: z <= 16'd94;
        47: z <= 16'd113;
        48: z <= -16'd103;
        49: z <= 16'd51;
        50: z <= -16'd98;
        51: z <= -16'd23;
        52: z <= -16'd67;
        53: z <= 16'd54;
        54: z <= 16'd1;
        55: z <= -16'd64;
        56: z <= -16'd45;
        57: z <= 16'd79;
        58: z <= 16'd119;
        59: z <= -16'd117;
        60: z <= 16'd67;
        61: z <= 16'd91;
        62: z <= 16'd115;
        63: z <= 16'd56;
        64: z <= -16'd27;
        65: z <= 16'd49;
        66: z <= 16'd3;
        67: z <= -16'd114;
        68: z <= 16'd56;
        69: z <= 16'd107;
        70: z <= -16'd78;
        71: z <= -16'd71;
        72: z <= 16'd95;
        73: z <= 16'd73;
        74: z <= -16'd125;
        75: z <= -16'd23;
        76: z <= 16'd18;
        77: z <= 16'd98;
        78: z <= -16'd38;
        79: z <= 16'd44;
        80: z <= 16'd21;
        81: z <= -16'd8;
        82: z <= -16'd107;
        83: z <= 16'd82;
        84: z <= -16'd81;
        85: z <= 16'd23;
        86: z <= -16'd110;
        87: z <= 16'd2;
        88: z <= -16'd26;
        89: z <= -16'd118;
        90: z <= 16'd13;
        91: z <= -16'd86;
        92: z <= 16'd101;
        93: z <= 16'd0;
        94: z <= 16'd98;
        95: z <= -16'd54;
        96: z <= -16'd79;
        97: z <= -16'd27;
        98: z <= -16'd40;
        99: z <= 16'd105;
        100: z <= -16'd48;
        101: z <= 16'd11;
        102: z <= -16'd94;
        103: z <= -16'd80;
        104: z <= -16'd44;
        105: z <= -16'd90;
        106: z <= 16'd25;
        107: z <= 16'd103;
        108: z <= -16'd120;
        109: z <= 16'd116;
        110: z <= 16'd19;
        111: z <= 16'd29;
        112: z <= -16'd20;
        113: z <= 16'd40;
        114: z <= -16'd17;
        115: z <= 16'd27;
        116: z <= -16'd65;
        117: z <= 16'd1;
        118: z <= -16'd99;
        119: z <= 16'd38;
        120: z <= 16'd11;
        121: z <= 16'd42;
        122: z <= 16'd80;
        123: z <= -16'd16;
        124: z <= -16'd86;
        125: z <= 16'd50;
        126: z <= 16'd59;
        127: z <= -16'd37;
      endcase
   end
endmodule

module layer_16_8_2_16_B_rom(clk, addr, z);
   input clk;
   input [3:0] addr;
   output logic signed [15:0] z;
   always_ff @(posedge clk) begin
      case(addr)
        0: z <= -16'd104;
        1: z <= -16'd109;
        2: z <= -16'd60;
        3: z <= -16'd24;
        4: z <= 16'd30;
        5: z <= -16'd25;
        6: z <= 16'd24;
        7: z <= 16'd115;
        8: z <= 16'd13;
        9: z <= -16'd78;
        10: z <= 16'd90;
        11: z <= 16'd21;
        12: z <= -16'd90;
        13: z <= -16'd19;
        14: z <= -16'd78;
        15: z <= 16'd18;
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
	layer_16_8_2_16_W_rom		rom_w(clk, addr_w, data_out_w);
	layer_16_8_2_16_B_rom		rom_b(clk, addr_b, data_out_b);

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

