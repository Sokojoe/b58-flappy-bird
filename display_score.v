module display_score(SW, LEDR, HEX0, CLOCK_50);
    input [17:0] SW;
    output [7:0] LEDR;
    output [7:0] HEX0;
    input CLOCK_50;

    wire ltd_clk;
    wire [3:0] q;

    rate_divider rd(
        .full_clk(CLOCK_50),
        .div_clk(ltd_clk),
        .select(SW[1:0])
    );

    display_counter dc(
        .enable(SW[4]),
        .par_load(SW[3]),
        .q(q[3:0]),
        .d(SW[17:14]),
        .clock(ltd_clk),
        .clear_b(SW[2])
    );

    hex_display hd(
        .IN(q[3:0]),
        .OUT(HEX0[7:0])
    );

endmodule

module rate_divider(full_clk, div_clk, select);
    input full_clk;
    input [1:0] select;
    output reg div_clk;

    reg [27:0] count;

    always @(posedge full_clk)
    begin
        count <= count + 1;
        if((count == 25000000 && select == 2'b01) || (count == 50000000 && select == 2'b10) || (count == 100000000 && select == 2'b11))
        begin
            count <= 0;
            div_clk <= !div_clk;
        end
    end
endmodule

module display_counter(enable, par_load, q, d, clock, clear_b);
	input par_load;
    input enable;
    input clock;
	input clear_b;
    input [3:0] d;
    output reg [3:0] q;

    always @(posedge clock) // triggered every time clock rises
    begin
        if (clear_b == 1'b0) // when Clear_b is 0...
            q <= 0; // set q to 0
        else if (par_load == 1'b1) // ...otherwise, check if parallel load
            q <= d; // load d
        else if (q == 4'b1111) // ...otherwise if q is the maximum counter value
            q <= 0; // reset q to 0
        else if (enable == 1'b1) // ...otherwise update q (only when Enable is 1)
            q <= q + 1'b1; // increment q
            // q <= q - 1'b1; // alternatively, decrement q
    end
endmodule

module hex_display(IN, OUT);
    input [3:0] IN;
	 output reg [7:0] OUT;
	 
	 always @(*)
	 begin
		case(IN[3:0])
			4'b0000: OUT = 7'b1000000;
			4'b0001: OUT = 7'b1111001;
			4'b0010: OUT = 7'b0100100;
			4'b0011: OUT = 7'b0110000;
			4'b0100: OUT = 7'b0011001;
			4'b0101: OUT = 7'b0010010;
			4'b0110: OUT = 7'b0000010;
			4'b0111: OUT = 7'b1111000;
			4'b1000: OUT = 7'b0000000;
			4'b1001: OUT = 7'b0011000;
			4'b1010: OUT = 7'b0001000;
			4'b1011: OUT = 7'b0000011;
			4'b1100: OUT = 7'b1000110;
			4'b1101: OUT = 7'b0100001;
			4'b1110: OUT = 7'b0000110;
			4'b1111: OUT = 7'b0001110;
			
			default: OUT = 7'b0111111;
		endcase

	end
endmodule
