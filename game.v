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
		LEDR
	);
	
	input CLOCK_50;
	input [9:0] SW;
	input [3:0] KEY;
	
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
//   wire [159:0] floor = 120'b0;
    wire [322:0] draw;

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
	.lose(lose)
	);

    display d0(
	.floor(draw),
	.clk(CLOCK_50),
	.resetn(resetn),
	.x(x),
	.y(y),
	.colour(colour)
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
			S_MOVE: next = stop ? S_STOP : S_MOVE;
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
	output reg [322:0] draw,
	output [9:0] LEDR
	output reg lose
    );
    
    //1011011100011011000000
    reg [27:0] count;
	 
	// reg [159:0] out;
	reg [319:0] obstacles;

	// the height control
    reg [4:0] height = 4'b00;
	 
	reg [4:0] start_falling = 5'b0;

    // going up or down, add or subtract height by 1
    reg going_up = 1'b1;
    
    always@(posedge clk) begin
		if (!resetn) begin
			count <= rate;
			height <= 4'b00;
			going_up <= 1'b1;
			lose <= 1'b0;
		end
        else if (start) begin
        	count <= rate;
        	height <= 4'b00;
         	draw <= 160'b0;
			obstacles[319:0] <= 320'b00000000000000000100000000000100000000001000000000000000001000000000000000000100000000000000010000000000110000000000000000010000000000000000010000000000000001000000000001000000000000100000000000000001000000000000000011000000000000000010000000000000000001000000000000110000000000001100000000000000000100000000000000001100;
			going_up <= 1'b1;
			lose <= 1'b0;
        end
		else begin
            if (count == 28'b0) begin
                count <= rate;
                draw = draw << 2;
				draw[1:0] = obstacles[319:318];
				obstacles[319:0] = {obstacles[317:0], obstacles[319:318]};
				// If height reaches ground lose the game
				if (height == 1'b0) 
					lose <= 1'b1
				// Maybe set max height aswell?
				// Not sure about height of pipes but add a check here to make sure height of bird is inbetween height of pipes
				if (height < obstacles[319:318])
					lose <= 1'b1
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
				
//					if (jump) begin
//						if (height == 2'b11) 
//							going_up = 1'b0;
//						if (going_up)
//							height = height + 1;
//						else 
//							height = height - 1;
//						if (height == 2'b00) 
//							going_up = 1'b1;
//					end
				draw[322:318] = height;
				end
            else
				count <= count - 1;
        end
    end
    	 
    assign LEDR[6] = going_up;
	 
    assign LEDR[9:8] = height;
    
endmodule

module display (
    input [322:0] floor,
    input clk,
	input resetn,
    output reg [7:0] x,
    output reg [6:0] y,
    output reg [2:0] colour
    );
    
    // initialization
    reg [7:0] x_init=8'd2;
    reg [8:0] y_init = 9'd84;
    reg [2:0] count = 3'b000;
	reg [12:0] counter = 13'b0;

	// counts from 0 to 9 for the first two pixel for the runner
	reg [4:0] runner_count = 5'b0;
	reg [4:0] runner_height = 3'b0;

	// copy of floor value, will do left shift on local value
	reg [322:0] local_draw;
	// reg [159:0] local_draw = 
    
    always@(posedge clk) begin
		if (!resetn) begin
			x_init <= 8'd2;
			y_init <= 9'd84;
			count <= 3'b000;
			counter <= 13'b0;
			local_draw <= floor<<2;
		end
		else begin
			if (counter < 13'd652) begin
				// fisrt 20 counts used to display runner
				if (counter < 13'd40) begin
					// fisrt or second pixel
					if (counter < 13'd20) 
						x <= 8'd0;
					else 
						x <= 8'd1;
					// stands for current display height
					runner_count = counter % 10;
					y = y_init - runner_count;
					// runner's height
					runner_height = floor[322:318];
					if (runner_count == 5'd0)
						colour = 3'b011;
					else if (runner_count < runner_height || runner_count > runner_height + 3)
						// dark part
						colour = 3'b011;
					else 
						// runner part
						colour = 3'b100;
				end
				else 
				// next 632 counts (158 pixels) to display obstacles 
				begin
					count = (counter-20) % 8;
					// x_init starts from 2
					x <= x_init + count[2];
					// the base line case
					if (count[1:0] == 2'b00) begin
						colour <= 3'b011;
						y <= y_init;
					end 
					else begin 
						/*if (counter < 1counter1'd8) begin
							// the runner casdarke
							// make the height of runner: draw * 2
							y_init = 7'd80 - local_draw[159:158] * 2;
							colour = 3'b101;
						end
						else begin
						*/
						//y_init = 7'd80;
						//if (count[1:0] == 2'b00)
						//	colour = 3'b110;
						//else 
						if (count[1:0] > local_draw[322:318])
							colour = 3'b011;
						else 
							colour = 3'b110;
						//end
						y <= y_init - count[1:0];
					end
					if (count == 3'b111)
					begin
						x_init <= x_init + 2;
						local_draw <= local_draw << 2;
					end
				end
				counter = counter + 1;
			end
			else begin 
				x_init <= 8'd2;
				y_init <= 9'd84;
				count <= 3'b000;
				counter <= 13'b0;
				local_draw <= floor << 2;
			end
		end
	end
endmodule
