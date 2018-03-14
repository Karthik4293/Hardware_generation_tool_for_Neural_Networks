module layer_8_8_1_8(clk, reset, s_valid, m_ready, data_in, m_valid, s_ready, data_out);
	parameter T = 8;
	input clk, reset, s_valid, m_ready;
	input signed [7:0]	data_in;
	output logic signed [7:0]	data_out;
	output m_valid, s_ready;

	logic signed[7:0] data_out1 ;
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
	input signed [7:0]	data_in;
	output signed [7:0]	data_out;
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
	logic [7:0] input_buffer;

	logic			computing, temp;
	logic [3:0]		input_counter;
	output logic [3:0]	output_counter;
	logic [3:0]  count;
	logic [3:0] block;
	parameter T=8, M=8, N=8, P=1, rank = 0;

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

module layer_8_8_1_8_W_rom(clk, addr, z);
   input clk;
   input [5:0] addr;
   output logic signed [7:0] z;
   always_ff @(posedge clk) begin
      case(addr)
        0: z <= -8'd2;
        1: z <= -8'd7;
        2: z <= 8'd1;
        3: z <= 8'd2;
        4: z <= 8'd5;
        5: z <= 8'd2;
        6: z <= 8'd1;
        7: z <= -8'd8;
        8: z <= 8'd6;
        9: z <= 8'd2;
        10: z <= -8'd6;
        11: z <= -8'd4;
        12: z <= 8'd6;
        13: z <= -8'd7;
        14: z <= -8'd8;
        15: z <= -8'd2;
        16: z <= -8'd2;
        17: z <= 8'd6;
        18: z <= -8'd8;
        19: z <= 8'd1;
        20: z <= -8'd1;
        21: z <= 8'd5;
        22: z <= -8'd2;
        23: z <= -8'd6;
        24: z <= 8'd3;
        25: z <= 8'd1;
        26: z <= 8'd0;
        27: z <= 8'd4;
        28: z <= 8'd0;
        29: z <= -8'd1;
        30: z <= 8'd3;
        31: z <= 8'd6;
        32: z <= 8'd0;
        33: z <= -8'd3;
        34: z <= 8'd0;
        35: z <= -8'd2;
        36: z <= 8'd7;
        37: z <= -8'd7;
        38: z <= -8'd2;
        39: z <= 8'd6;
        40: z <= 8'd3;
        41: z <= 8'd0;
        42: z <= -8'd6;
        43: z <= 8'd2;
        44: z <= 8'd2;
        45: z <= -8'd6;
        46: z <= -8'd8;
        47: z <= -8'd8;
        48: z <= -8'd8;
        49: z <= -8'd7;
        50: z <= 8'd1;
        51: z <= -8'd1;
        52: z <= 8'd6;
        53: z <= 8'd7;
        54: z <= 8'd2;
        55: z <= 8'd2;
        56: z <= 8'd0;
        57: z <= -8'd6;
        58: z <= -8'd2;
        59: z <= -8'd8;
        60: z <= 8'd1;
        61: z <= -8'd7;
        62: z <= 8'd7;
        63: z <= -8'd6;
      endcase
   end
endmodule

module layer_8_8_1_8_B_rom(clk, addr, z);
   input clk;
   input [2:0] addr;
   output logic signed [7:0] z;
   always_ff @(posedge clk) begin
      case(addr)
        0: z <= -8'd2;
        1: z <= -8'd1;
        2: z <= 8'd0;
        3: z <= -8'd2;
        4: z <= 8'd1;
        5: z <= 8'd6;
        6: z <= -8'd4;
        7: z <= -8'd4;
      endcase
   end
endmodule

module datapath(clk, reset, data_in, addr_x, wr_en_x, addr_w, accum_src, data_out, enable_accum, addr_b, output_counter);
	input				clk, reset, wr_en_x, accum_src, enable_accum;
	input signed [7:0]		data_in;
	input [5:0]			addr_w;
	input [2:0]			addr_x;
	input [2:0]			addr_b;
	input [3:0]			output_counter;

	output logic signed [7:0]	data_out;
	logic signed [7:0]		data_out_x, data_out_w, data_out_b;
	logic signed [7:0]		mult_out, add_out, mux_out, mult_out_temp;

	memory #(8, 8, 3)		mem_x(clk, data_in, data_out_x, addr_x, wr_en_x);
	layer_8_8_1_8_W_rom		rom_w(clk, addr_w, data_out_w);
	layer_8_8_1_8_B_rom		rom_b(clk, addr_b, data_out_b);

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

