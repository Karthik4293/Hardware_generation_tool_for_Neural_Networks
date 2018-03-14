module layer_8_8_1_12(clk, reset, s_valid, m_ready, data_in, m_valid, s_ready, data_out);
	parameter T = 12;
	input clk, reset, s_valid, m_ready;
	input signed [11:0]	data_in;
	output logic signed [11:0]	data_out;
	output m_valid, s_ready;

	logic signed[11:0] data_out1 ;
	logic m_valid1 ;
	logic s_ready1 ;
	logic [0:0] out_count;

	mvma#(.rank(0))  mvma_8_8_1(clk, reset, s_valid, m_ready, data_in, m_valid1, s_ready1, data_out1);

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

module mvma(clk, reset, s_valid, m_ready, data_in, m_valid, s_ready, data_out);
	input			clk, reset, s_valid, m_ready;
	input signed [11:0]	data_in;
	output signed [11:0]	data_out;
	output			m_valid, s_ready;
	logic [5:0]		addr_w;
	logic [2:0]		addr_x;
	logic [2:0]		addr_b;
	logic			wr_en_x, accum_src, enable_accum;
	logic [3:0]		output_counter;
	parameter rank = 0;

	control#(.rank(rank))			ctrl(clk, reset, s_valid, m_ready, addr_x, wr_en_x, addr_w, accum_src, m_valid, s_ready, enable_accum, addr_b, output_counter);
	datapath		dpth(clk, reset, data_in, addr_x, wr_en_x, addr_w, accum_src, data_out, enable_accum, addr_b, output_counter);
endmodule

module control(clk, reset, s_valid, m_ready, addr_x, wr_en_x, addr_w, accum_src, m_valid, s_ready, accum_en, addr_b, output_counter);
	input			clk, reset, s_valid, m_ready; 
	output logic [5:0]	addr_w;
	output logic [2:0]	addr_x;
	output logic [2:0]	addr_b;
	output logic		wr_en_x, accum_src, m_valid, s_ready, accum_en;

	logic [1:0] d,c;
	logic [11:0] input_buffer;

	logic			computing, temp;
	logic [3:0]		input_counter;
	output logic [3:0]	output_counter;
	logic [3:0]  count;
	logic [3:0] block;
	parameter T=12, M=8, N=8, P=1, rank = 0;

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

module layer_8_8_1_12_W_rom(clk, addr, z);
   input clk;
   input [5:0] addr;
   output logic signed [11:0] z;
   always_ff @(posedge clk) begin
      case(addr)
        0: z <= -12'd24;
        1: z <= -12'd21;
        2: z <= 12'd2;
        3: z <= -12'd26;
        4: z <= -12'd7;
        5: z <= 12'd30;
        6: z <= -12'd30;
        7: z <= -12'd32;
        8: z <= 12'd16;
        9: z <= -12'd26;
        10: z <= -12'd20;
        11: z <= -12'd19;
        12: z <= -12'd14;
        13: z <= 12'd30;
        14: z <= 12'd29;
        15: z <= 12'd2;
        16: z <= 12'd6;
        17: z <= -12'd6;
        18: z <= 12'd2;
        19: z <= 12'd15;
        20: z <= 12'd12;
        21: z <= 12'd14;
        22: z <= -12'd22;
        23: z <= 12'd6;
        24: z <= -12'd4;
        25: z <= -12'd3;
        26: z <= -12'd15;
        27: z <= 12'd29;
        28: z <= -12'd7;
        29: z <= -12'd28;
        30: z <= -12'd17;
        31: z <= 12'd2;
        32: z <= -12'd17;
        33: z <= 12'd17;
        34: z <= 12'd8;
        35: z <= 12'd9;
        36: z <= 12'd16;
        37: z <= 12'd10;
        38: z <= 12'd9;
        39: z <= 12'd0;
        40: z <= 12'd16;
        41: z <= 12'd21;
        42: z <= 12'd13;
        43: z <= -12'd30;
        44: z <= 12'd19;
        45: z <= 12'd11;
        46: z <= 12'd5;
        47: z <= -12'd6;
        48: z <= -12'd27;
        49: z <= -12'd25;
        50: z <= -12'd23;
        51: z <= 12'd17;
        52: z <= 12'd22;
        53: z <= -12'd12;
        54: z <= -12'd9;
        55: z <= -12'd14;
        56: z <= 12'd17;
        57: z <= 12'd8;
        58: z <= -12'd16;
        59: z <= -12'd21;
        60: z <= 12'd12;
        61: z <= -12'd1;
        62: z <= 12'd13;
        63: z <= 12'd27;
      endcase
   end
endmodule

module layer_8_8_1_12_B_rom(clk, addr, z);
   input clk;
   input [2:0] addr;
   output logic signed [11:0] z;
   always_ff @(posedge clk) begin
      case(addr)
        0: z <= -12'd16;
        1: z <= -12'd11;
        2: z <= 12'd4;
        3: z <= -12'd32;
        4: z <= 12'd31;
        5: z <= -12'd18;
        6: z <= 12'd0;
        7: z <= 12'd15;
      endcase
   end
endmodule

module datapath(clk, reset, data_in, addr_x, wr_en_x, addr_w, accum_src, data_out, enable_accum, addr_b, output_counter);
	input				clk, reset, wr_en_x, accum_src, enable_accum;
	input signed [11:0]		data_in;
	input [5:0]			addr_w;
	input [2:0]			addr_x;
	input [2:0]			addr_b;
	input [3:0]			output_counter;

	output logic signed [11:0]	data_out;
	logic signed [11:0]		data_out_x, data_out_w, data_out_b;
	logic signed [11:0]		mult_out, add_out, mux_out, mult_out_temp;

	memory #(12, 8, 3)		mem_x(clk, data_in, data_out_x, addr_x, wr_en_x);
	layer_8_8_1_12_W_rom		rom_w(clk, addr_w, data_out_w);
	layer_8_8_1_12_B_rom		rom_b(clk, addr_b, data_out_b);

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

