/*
 * Dot Runner
 * CSCB58 Winter 2017 Final Project 
 * Team members:
 * 	Changyu Bi
 *	Jiachen He
 */

module final_project(
		CLOCK_50,
		KEY,
		SW,
		VGA_CLK,
		VGA_HS,
		VGA_VS,
		VGA_BLANK_N,
		VGA_SYNC_N,
		VGA_R,
		VGA_G,
		VGA_B,
		LEDR,
		HEX0,
		HEX1,
		HEX2,
		HEX3
	);
	
	input CLOCK_50;
	input [9:0] SW;
	input [3:0] KEY;
	output [7:0] HEX0;
	output [7:0] HEX1;
	output [7:0] HEX2;
	output [7:0] HEX3;

	
	output VGA_CLK;
	output VGA_HS;
	output VGA_VS;
	output VGA_BLANK_N;
	output VGA_SYNC_N;
	output [9:0] VGA_R;
	output [9:0] VGA_G;
	output [9:0] VGA_B;
	output [9:0] LEDR;
	
	wire [2:0] colour;
	wire [7:0] x;
	wire [6:0] y;
	
	wire resetn = KEY[0]; 
	//wire writeEn = ~KEY[1];
	
	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(1),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "black.mif";
		
//    wire [319:0] new_array = 320'b00000000001000000000010000000001000000000010000000000000000010000000000000000001000000000000000100000000001100000000000000000100000000000000000100000000000000010000000000010000000000001000000000000000010000000000000000110000000000000000100000000000000000010000000000001100000000000011000000000000000001000000000000000011;
    wire [27:0] rate = 28'b0000001011011100011011000000;
	 wire [27:0] score;
//   wire [159:0] floor = 120'b0;
    wire [325:0] draw;

    wire start, move, lose;
    
    control c(
	.clk(CLOCK_50),
	.go(~KEY[2]),
	.stop(~KEY[1]),
    .start(start),
	.resetn(resetn),
	.move(move),
	.lose(lose)
	);

    // key 3 used as jump button
    datapath d(
	.clk(CLOCK_50),
	.start(start),
	.move(move),
	.jump(~KEY[3]),
	.rate(rate),
	.resetn(resetn),
	.draw(draw),
	.LEDR(LEDR[9:0]),
	.score(score),
	.lose(lose)
	);

    display d0(
	.floor(draw),
	.clk(CLOCK_50),
	.resetn(resetn),
	.x(x),
	.y(y),
	.colour(colour),
	.counter(counter)
	);

//	renderPipes d1(
//	.local_draw(local_draw),
//	.counter(counter),
//	.clk(CLOCK_50),
//	.x(x),
//	.y(y),
//	.colour(colour)
//	);
	
	hex_display h0(
		.IN(score[3:0]),
		.OUT(HEX0)
	);

	hex_display h1(
		.IN(score[7:4]),
		.OUT(HEX1)
	);	

	hex_display h2(
		.IN(score[11:8]),
		.OUT(HEX2)
	);

	hex_display h3(
		.IN(score[15:12]),
		.OUT(HEX3)
	);
endmodule


module control(
	input clk,
	input go,
	input stop,
	input resetn,
	input lose,
	output reg start,
	output reg move
	);
	
	reg [5:0] cur, next;
	
	localparam S_READY = 5'd0,
		  S_READY_WAIT = 5'd1,
		  S_MOVE  = 5'd2,
		  S_STOP  = 5'd3;
	
	// Add to state table lose => S_READY
	always@(*)
	begin: state_table
		case (cur)
			S_READY: next = go ? S_READY_WAIT : S_READY;
			S_READY_WAIT: next = S_MOVE;
			S_MOVE: next = stop ? S_STOP : (lose ? S_READY : S_MOVE);
			S_STOP: next = S_READY;
			default: next = S_READY;
		endcase
	end
	
	always @(*)
	begin: enable_signals
		start = 1'b0;
		move = 1'b0;
		
		case (cur) 
			S_READY: begin 
				start = 1'b1;
			end
			S_MOVE: begin 
				move = 1'b1;
			end
			default: begin
			end
		endcase	
	end
	
	always@(posedge clk) 
	begin: state_FFs
		if (!resetn)
			cur <= S_READY;
		else 
			cur <= next;
	end
endmodule


module datapath (
    input clk,
    input start,
    input move,
    input jump,
    input [27:0] rate,	
	input resetn,
	output [9:0] LEDR,
	output reg [27:0] score,
	output reg [1112:0] draw,
	output reg lose
    );
	    
    //1011011100011011000000
    reg [27:0] count;
	 
	reg [1112:0] obstacles;

	// the height control
    reg [6:0] height = 7'd40;
	 
	reg [4:0] start_falling = 5'b0;

    // going up or down, add or subtract height by 1
    reg going_up = 1'b1;
    
    always@(posedge clk) begin
		if (!resetn) begin
			count <= rate;
        	height <= 7'd40;
			going_up <= 1'b1;
			score <= 14'b0;
			lose <= 1'b0;
		end
        else if (start) begin
        	count <= rate;
        	height <= 7'd40;
         draw <= 1112'b0;
			obstacles[1105:0] <= 1106'b0000000_0000000_0000000_0000000_0000000_0000000_0000000_1100000_0000000_0000000_0000000_0000000_1110010_0000000_0000000_0000000_1111000_0000000_0000000_0000000_0000000_0000000_0000000_110100_0000000_0000000_0000000_0000000_0000000_1110100_0000000_0000000_0000000_0000000_0101000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000_0000000;
			going_up <= 1'b1;
			score <= 14'b0;
			lose <= 1'b0;
        end
		else begin
            if (count == 28'b0) begin
                count <= rate;
				score = score + 1;
                draw = draw << 7;
				draw[7:0] = obstacles[1105:1098];
				obstacles[1112:0] = {obstacles[1105:0], obstacles[1112:1106]};
				// If height reaches ground lose the game
				if (height == 7'd0) 
					lose <= 1'b1;
				if (height == 7'd80) 
					lose <= 1'b1;
				// Maybe set max height aswell?
				// Not sure about height of pipes but add a check here to make sure height of bird is inbetween height of pipes
				if (height < obstacles[319:318])
					lose <= 1'b1;
				// height will change if it is already jumping or jump button is pushed
				if (jump) begin
					start_falling = 5'b1111;
					going_up = 1'b1;			
					end
				else if (start_falling > 0)
					start_falling = start_falling - 1;
				else 
					going_up = 1'b0;
				if (going_up)
					height = height + 1;
				else
					height = height -1;

				draw[1112:1106] = height;
				end
            else
				count <= count - 1;
        end
    end
    	 
    assign LEDR[6] = going_up;
	 
    assign LEDR[9:8] = height;
    
endmodule

module display (
    input [1112:0] floor,
    input clk,
	 input resetn,
    output reg [7:0] x,
    output reg [6:0] y,
    output reg [2:0] colour,
	 output reg [15:0] counter
    );
    
   // initialization
   reg [7:0] x_init= 8'd2;
   reg [8:0] y_init = 9'd84;

	// counts from 0 to 19 for the first two pixel for the runner
	reg [8:0] runner_count = 9'b0;
	reg [6:0] runner_height = 7'b0;

	// copy of floor value, will do left shift on local value
	reg [1112:0] local_draw;
	
	reg [7:0] y_pixel;
	reg [7:0] pipe_height;  
	reg [8:0] count;

    always@(posedge clk) begin
		if (!resetn) begin
			x_init <= 8'd2;
			y_init <= 9'd84;		
			counter <= 15'b0;
		end
		else begin
			if (counter < 15'd12800) begin
				// fisrt 160 counts used to display runner
				if (counter < 15'd160) begin
					// fisrt or second pixel
					if (counter < 15'd80) 
						x <= 8'd0;
					else 
						x <= 8'd1;
					// stands for current display height
					runner_count = counter % 80;
					y = y_init - runner_count;
					// runner's height
					runner_height = floor[1112:1106];
					if (runner_count == 7'd0)
						colour = 3'b011;
					else if (runner_count < runner_height || runner_count > runner_height + 3)
						// dark part
						colour = 3'b011;
					else 
						// runner part
						colour = 3'b100;
				end 
				else begin
					count = (counter-160) % 320;
					if (count < 80)
						x <= x_init;
					if (count < 160)
						x <= x_init + 1;
					if (count < 240)
						x <= x_init + 2;
					if (count < 320)
						x <= x_init + 3;

					y_pixel = count % 80;
					y <= y_init - y_pixel;
					pipe_height = local_draw[1105:1098];
					if (y_pixel < pipe_height || y_pixel > pipe_height + 4'd12)
						colour = 3'b110;
					else 
						colour = 3'b011;

					if (pipe_height == 7'd0) 
						colour = 3'b011;

					if (count == 15'd320) begin
						x_init <= x_init + 4;
						local_draw <= local_draw << 7;
					end
				end
				counter = counter + 1;
			end
			else begin 
				x_init <= 8'd2;
				y_init <= 9'd84;
				counter <= 13'b0;
				local_draw <= floor << 7;
			end
		end
	end
endmodule

//module renderPipes (
//    input [1105:0] draw,
//	 input [15:0] counter,
//    input clk,
//    output reg [7:0] x,
//    output reg [6:0] y,
//    output reg [2:0] colour
//    );
//	 
//   reg [7:0] x_init = 8'd2;
//	reg [8:0] y_init = 9'd84;
//	reg [7:0] y_pixel;
//	reg [7:0] pipe_height;
//	reg [1105:0] local_draw;
//
//   always@(posedge clk) begin
//
//		reg [2:0] count = 3'b000;
//
//		if (counter < 15'd12800) begin
//			count = (counter-160) % 320;
//			if (count < 80)
//				x <= x_init;
//			if (count < 160)
//				x <= x_init + 1;
//			if (count < 240)
//				x <= x_init + 2;
//			if (count < 320)
//				x <= x_init + 3;
//
//			y_pixel = count % 80;
//			y <= y_init - y_pixel;
//			pipe_height = local_draw[1105:1098];
//			if (y_pixel < pipe_height || y_pixel > pipe_height + 4'd12)
//				colour = 3'b110;
//			else 
//				colour = 3'b011;
//
//			if (pipe_height == 7'd0) 
//				colour = 3'b011;
//
//			if (count == 15'd320) begin
//				x_init <= x_init + 4;
//				local_draw <= local_draw << 7;
//			end
//		end	
//	end
//endmodule

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
