module Test_Module(	iRed,
					iGreen,
					iBlue,
					oRed,
					oGreen,
					oBlue,
					iCLK,
					iRST_N
						);
						
`include "TestParams.h"
						
input		[9:0]	iRed;
input		[9:0]	iGreen;
input		[9:0]	iBlue;

output	reg	[9:0]	oRed;
output	reg	[9:0]	oGreen;
output	reg	[9:0]	oBlue;

input				iCLK;
input				iRST_N;

wire		[9:0]	mRed;
wire		[9:0]	mGreen;
wire		[9:0]	mBlue;

wire		[31:0]	rgb;
wire		[31:0]	r;
wire		[31:0]	g;

wire		[31:0]	r2;
wire		[31:0]	f1r;
wire		[31:0]	f2r;

wire		[31:0]	w;

//	Internal Registers and Wires
reg		[12:0]		H_Cont;
reg		[12:0]		V_Cont;

reg					mVGA_H_SYNC;
reg					mVGA_V_SYNC;

wire	[9:0]	gray;

/*
assign	gray	=	(((iRed + iGreen + iBlue) / 3) < 127) ?  0 : 
					((((iRed + iGreen + iBlue) / 3) < 383) ? 255 : 
					(((((iRed + iGreen + iBlue) / 3) < 639) ? 511 :  
					((((((iRed + iGreen + iBlue) / 3) < 895) ? 767 : 1023))))));
	*/

assign rgb		= adder(int_to_float(iRed), adder(int_to_float(iGreen), int_to_float(iBlue)));
assign r		= divider(int_to_float(iRed), rgb); //iRed/(iRed + iGreen + iBlue);
assign g		= divider(int_to_float(iGreen), rgb); //iGreen/(iRed + iGreen + iBlue);

assign r2		= multiplier(r,r);
assign f1r		= adder(multiplier(32'hbfb020c5, r2), adder(multiplier(32'h3f8982aa, r), 32'h40200000));  //-1.376*r*r + 1.0743*r + 2.5;
assign f2r		= adder(multiplier(32'hbf46a7f0, r2), adder(multiplier(32'h3f0f62b7, r), 32'h3e3851ec));  //-0.776*r*r + 0.5601*r + 0.18;

//assign w		= adder(multiplier(adder(r,32'h3ea8f5c3),adder(r,32'h3ea8f5c3)), multiplier(adder(g,32'h3ea8f5c3),adder(g,32'h3ea8f5c3)));  //(r - 0.33) * (r - 0.33) + (g - 0.33) * (g - 0.33);
assign w		= adder(r2, adder(multiplier(g,g),adder(multiplier(32'hbf28f5c3, adder(r,g)),32'h3e5f06f7)));  //(r2+(g2+(-0.66(r+g)+0.2178)))



assign mRed		= iRed;
assign mGreen	= iGreen;
assign mBlue	= iBlue;

always@(posedge iCLK or negedge iRST_N)
	begin
	
	// calculate f1r, f2r, and w
	//int_to_float 	m1	(
	// end calculations
		if (!iRST_N)
			begin
				oRed <= 0;
				oGreen <= 0;
                oBlue <= 0;
			end
		else //if (greater_than(f1r, g) && greater_than(g, f2r) && greater_than(w, 32'h3a83126f))  //((f1r > g) && (g > f2r) && (w > 0.001))
			begin
				oRed <= mRed;
				oGreen <= mGreen;
				oBlue <= mBlue;
			end/*
		else
			begin
				oRed <= 0;
				oGreen <= 0;
				oBlue <= 0;
			end*/
	end


//	H_Sync Generator, Ref. 25.175 MHz Clock
always@(posedge iCLK or negedge iRST_N)
begin
	if(!iRST_N)
	begin
		H_Cont		<=	0;
		mVGA_H_SYNC	<=	0;
	end
	else
	begin
		//	H_Sync Counter
		if( H_Cont < H_SYNC_TOTAL )
		H_Cont	<=	H_Cont+1;
		else
		H_Cont	<=	0;
		//	H_Sync Generator
		if( H_Cont < H_SYNC_CYC )
		mVGA_H_SYNC	<=	0;
		else
		mVGA_H_SYNC	<=	1;
	end
end

//	V_Sync Generator, Ref. H_Sync
always@(posedge iCLK or negedge iRST_N)
begin
	if(!iRST_N)
	begin
		V_Cont		<=	0;
		mVGA_V_SYNC	<=	0;
	end
	else
	begin
		//	When H_Sync Re-start
		if(H_Cont==0)
		begin
			//	V_Sync Counter
			if( V_Cont < V_SYNC_TOTAL )
			V_Cont	<=	V_Cont+1;
			else
			V_Cont	<=	0;
			//	V_Sync Generator
			if(	V_Cont < V_SYNC_CYC )
			mVGA_V_SYNC	<=	0;
			else
			mVGA_V_SYNC	<=	1;
		end
	end
end

function [31:0] teste;
input [31:0] a;

begin
	teste = a;
end
endfunction


function [31:0] multiplier;
input 	[31:0]	a;
input 	[31:0]	b;
reg 	[31:0]	z;
reg		[23:0]	a_m, b_m, z_m;
reg		[9:0]	a_e, b_e, z_e;
reg				a_s, b_s, z_s;
reg				guard, round_bit, sticky;
reg		[49:0]	product;
reg				finish;

begin

// Unpack
	a_m = a[22 : 0];
	b_m = b[22 : 0];
	a_e = a[30 : 23] - 127;
	b_e = b[30 : 23] - 127;
	a_s = a[31];
	b_s = b[31];

// Special Cases
	finish = 0;
    // if a is NaN or b is NaN return NaN 
	if ((a_e == 128 && a_m != 0) || (b_e == 128 && b_m != 0)) begin
		z[31] = 1;
		z[30:23] = 255;
		z[22] = 1;
		z[21:0] = 0;
		
		finish = 1;
	//if a is inf return inf
	end else if (a_e == 128) begin
		z[31] = a_s ^ b_s;
		z[30:23] = 255;
		z[22:0] = 0;

		finish = 1;
		//if b is zero return NaN
		if ($signed(b_e == -127) && (b_m == 0)) begin
			z[31] = 1;
			z[30:23] = 255;
			z[22] = 1;
			z[21:0] = 0;

			finish = 1;
		end
	//if b is inf return inf
	end else if (b_e == 128) begin
		z[31] = a_s ^ b_s;
		z[30:23] = 255;
		z[22:0] = 0;

		finish = 1;
	//if a is zero return zero
	end else if (($signed(a_e) == -127) && (a_m == 0)) begin
		z[31] = a_s ^ b_s;
		z[30:23] = 0;
		z[22:0] = 0;

		finish = 1;
	//if b is zero return zero
	end else if (($signed(b_e) == -127) && (b_m == 0)) begin
		z[31] = a_s ^ b_s;
		z[30:23] = 0;
		z[22:0] = 0;
		
		finish = 1;
	end else begin
		//Denormalised Number a
		if ($signed(a_e) == -127) begin
			a_e = -126;
		end else begin
			a_m[23] = 1;
		end
		// Denormalised Number b
		if ($signed(b_e) == -127) begin
			b_e = -126;
		end else begin
			b_m[23] = 1;
		end
	end
	
	
	if (finish == 0) begin
		// Normalize a
		repeat (30) begin
			if (~a_m[23]) begin
			  a_m = a_m << 1;
			  a_e = a_e - 1;
			end
		end
		
		// Normalize b
		repeat (30) begin
			if (~b_m[23]) begin
			  b_m = b_m << 1;
			  b_e = b_e - 1;
			end
		end

		// Multiply 0
        z_s = a_s ^ b_s;
        z_e = a_e + b_e + 1;
        product = a_m * b_m * 4;

		// Multiply 1
        z_m = product[49:26];
        guard = product[25];
        round_bit = product[24];
        sticky = (product[23:0] != 0);
        
        // Normalize mantissa
		repeat (30) begin
			if (z_m[23] == 0) begin
			  z_e = z_e - 1;
			  z_m = z_m << 1;
			  z_m[0] = guard;
			  guard = round_bit;
			  round_bit = 0;
			end
        end
        
        // Normalize Expoente
		repeat (30) begin
			if ($signed(z_e) < -126) begin
			  z_e = z_e + 1;
			  z_m = z_m >> 1;
			  guard = z_m[0];
			  round_bit = guard;
			  sticky = sticky | round_bit;
			end
		end
        
        // Round
        if (guard && (round_bit | sticky | z_m[0])) begin
          z_m = z_m + 1;
          if (z_m == 24'hffffff) begin
            z_e =z_e + 1;
          end
        end
        
        // Pack
        z[22 : 0] = z_m[22:0];
        z[30 : 23] = z_e[7:0] + 127;
        z[31] = z_s;
        if ($signed(z_e) == -126 && z_m[23] == 0) begin
          z[30 : 23] = 0;
        end
        //if overflow occurs, return inf
        if ($signed(z_e) > 127) begin
          z[22 : 0] = 0;
          z[30 : 23] = 255;
          z[31] = z_s;
        end
	end
	
	// Return 
	multiplier = z;
end
endfunction


function [31:0] divider;
input 	[31:0]	a;
input 	[31:0]	b;
reg 	[31:0]	z;
reg		[23:0]	a_m, b_m, z_m;
reg		[9:0]	a_e, b_e, z_e;
reg				a_s, b_s, z_s;
reg				guard, round_bit, sticky;
reg     [50:0]  quotient, divisor, dividend, remainder;
reg     [5:0]   count;
reg				finish;

begin
// Unpack
	a_m = a[22 : 0];
	b_m = b[22 : 0];
	a_e = (a[30 : 23]) - 127;
	b_e = (b[30 : 23]) - 127;
	a_s = a[31];
	b_s = b[31];

// Special Cases
	finish = 0;
    // if a is NaN or b is NaN return NaN 
	if ((a_e == 128 && a_m != 0) || (b_e == 128 && b_m != 0)) begin
		z[31] = 1;
		z[30:23] = 255;
		z[22] = 1;
		z[21:0] = 0;
		
		finish = 1;
    //if a is inf and b is inf return NaN 
    end else if ((a_e == 128) && (b_e == 128)) begin
        z[31] = 1;
        z[30:23] = 255;
        z[22] = 1;
        z[21:0] = 0;

		finish = 1;
	//if a is inf return inf
	end else if (a_e == 128) begin
		z[31] = a_s ^ b_s;
		z[30:23] = 255;
		z[22:0] = 0;

		finish = 1;
		//if b is zero return NaN
		if ($signed(b_e == -127) && (b_m == 0)) begin
			z[31] = 1;
			z[30:23] = 255;
			z[22] = 1;
			z[21:0] = 0;

			finish = 1;
		end
	//if b is inf return zero
	end else if (b_e == 128) begin
		z[31] = a_s ^ b_s;
		z[30:23] = 0;
		z[22:0] = 0;

		finish = 1;
	//if a is zero return zero
	end else if (($signed(a_e) == -127) && (a_m == 0)) begin
		z[31] = a_s ^ b_s;
		z[30:23] = 0;
		z[22:0] = 0;

		finish = 1;
		//if b is zero return NaN
        if (($signed(b_e) == -127) && (b_m == 0)) begin
            z[31] = 1;
            z[30:23] = 255;
            z[22] = 1;
            z[21:0] = 0;

    		finish = 1;
        end
	//if b is zero return inf
	end else if (($signed(b_e) == -127) && (b_m == 0)) begin
		z[31] = a_s ^ b_s;
		z[30:23] = 255;
		z[22:0] = 0;
		
		finish = 1;
	end else begin
		//Denormalised Number a
		if ($signed(a_e) == -127) begin
			a_e = -126;
		end else begin
			a_m[23] = 1;
		end
		// Denormalised Number b
		if ($signed(b_e) == -127) begin
			b_e = -126;
		end else begin
			b_m[23] = 1;
		end
	end
	
	
	if (finish == 0) begin
		// Normalize a
		repeat (30) begin
			if (~a_m[23]) begin
			  a_m = a_m << 1;
			  a_e = a_e - 1;
			end
		end
		
		// Normalize b
		repeat (30) begin
			if (~b_m[23]) begin
			  b_m = b_m << 1;
			  b_e = b_e - 1;
			end
		end

		// Divide 0
        z_s = a_s ^ b_s;
        z_e = a_e - b_e;
        quotient = 0;
        remainder = 0;
        dividend = a_m << 27;
        divisor = b_m;

        repeat (50)
        begin
    		// Divide 1
            quotient = quotient << 1;
            remainder = remainder << 1;
            remainder[0] = dividend[50];
            dividend = dividend << 1;
            
            // Divide 2
            if (remainder >= divisor) begin
                quotient[0] = 1;
                remainder = remainder - divisor;
            end
        end
        // Divide 3
        z_m = quotient[26:3];
        guard = quotient[2];
        round_bit = quotient[1];
        sticky = quotient[0] | (remainder != 0);
        
        // Normalize 1
		repeat (30) begin
			if (z_m[23] == 0 && $signed(z_e) > -126) begin
			  z_e = z_e - 1;
			  z_m = z_m << 1;
			  z_m[0] = guard;
			  guard = round_bit;
			  round_bit = 0;
			end
		end
        
        // Normalize Expoente
		repeat (30) begin
			if ($signed(z_e) < -126) begin
			  z_e = z_e + 1;
			  z_m = z_m >> 1;
			  guard = z_m[0];
			  round_bit = guard;
			  sticky = sticky | round_bit;
			end
        end
        
        // Round
        if (guard && (round_bit | sticky | z_m[0])) begin
          z_m = z_m + 1;
          if (z_m == 24'hffffff) begin
            z_e =z_e + 1;
          end
        end
        
        // Pack
        z[22 : 0] = z_m[22:0];
        z[30 : 23] = z_e[7:0] + 127;
        z[31] = z_s;
        if ($signed(z_e) == -126 && z_m[23] == 0) begin
          z[30 : 23] = 0;
        end
        //if overflow occurs, return inf
        if ($signed(z_e) > 127) begin
          z[22 : 0] = 0;
          z[30 : 23] = 255;
          z[31] = z_s;
        end
	end
	
    // Return 
    divider = z;
end
endfunction


function [31:0] adder;
input 	[31:0]	a;
input 	[31:0]	b;
reg 	[31:0]	z;
reg		[27:0]	a_m, b_m;
reg		[23:0]	z_m;
reg		[9:0]	a_e, b_e, z_e;
reg				a_s, b_s, z_s;
reg				guard, round_bit, sticky;
reg     [27:0]  sum;
reg				finish;

begin
// Unpack
	a_m = {a[22 : 0], 4'd0};
	b_m = {b[22 : 0], 4'd0};
	a_e = (a[30 : 23]) - 127;
	b_e = (b[30 : 23]) - 127;
	a_s = a[31];
	b_s = b[31];

// Special Cases
	finish = 0;
    // if a is NaN or b is NaN return NaN 
	if ((a_e == 128 && a_m != 0) || (b_e == 128 && b_m != 0)) begin
		z[31] = 1;
		z[30:23] = 255;
		z[22] = 1;
		z[21:0] = 0;
		
		finish = 1;
	//if a is inf return inf
	end else if (a_e == 128) begin
		z[31] = a_s;
		z[30:23] = 255;
		z[22:0] = 0;

		finish = 1;
	//if b is inf return inf
	end else if (b_e == 128) begin
		z[31] = b_s;
		z[30:23] = 255;
		z[22:0] = 0;

		finish = 1;
	//if a is zero return b
	end else if (($signed(a_e) == -127) && (a_m == 0)) begin
		z[31] = b_s;
		z[30:23] = (b_e[7:0]) + 127;
		z[22:0] = b_m[26:4];

		finish = 1;
	//if b is zero return a
	end else if (($signed(b_e) == -127) && (b_m == 0)) begin
		z[31] = a_s;
		z[30:23] = (a_e[7:0]) + 127;
		z[22:0] = a_m[26:4];
		
		finish = 1;
	end else begin
		//Denormalised Number a
		if ($signed(a_e) == -127) begin
			a_e = -126;
		end else begin
			a_m[23] = 1;
		end
		// Denormalised Number b
		if ($signed(b_e) == -127) begin
			b_e = -126;
		end else begin
			b_m[23] = 1;
		end
	end
	
	
	if (finish == 0) begin
	
	    // Align
	    repeat (30) begin
			if ($signed(a_e) != $signed(b_e)) begin
				if ($signed(a_e) > $signed(b_e)) begin
					b_e = b_e + 1;
					b_m = b_m >> 1;
					b_m[0] = b_m[0] | b_m[1];
				end else if ($signed(a_e) < $signed(b_e)) begin
					a_e = a_e + 1;
					a_m = a_m >> 1;
					a_m[0] = a_m[0] | a_m[1];
				end
			end
        end
        
        // Add 0
        z_e = a_e;
        if (a_s == b_s) begin
            sum = a_m + b_m;
            z_s = a_s;
        end else begin
            if (a_m >= b_m) begin
                sum = a_m - b_m;
                z_s = a_s;
            end else begin
                sum = b_m - a_m;
                z_s = b_s;
            end
        end
        
        // Add 1
        if (sum[27]) begin
            z_m = sum[27:4];
            guard = sum[3];
            round_bit = sum[2];
            sticky = sum[1] | sum[0];
            z_e = z_e + 1;
        end else begin
            z_m = sum[26:3];
            guard = sum[2];
            round_bit = sum[1];
            sticky = sum[0];
        end
        
        // Normalize 1
        repeat (30) begin
			if (z_m[23] == 0 && $signed(z_e) > -126) begin
			  z_e = z_e - 1;
			  z_m = z_m << 1;
			  z_m[0] = guard;
			  guard = round_bit;
			  round_bit = 0;
			end
		end
        // Normalize 2
        repeat (30) begin
			if ($signed(z_e) < -126) begin
			  z_e = z_e + 1;
			  z_m = z_m >> 1;
			  guard = z_m[0];
			  round_bit = guard;
			  sticky = sticky | round_bit;
			end
		end
        
        // Round
        if (guard && (round_bit | sticky | z_m[0])) begin
          z_m = z_m + 1;
          if (z_m == 24'hffffff) begin
            z_e = z_e + 1;
          end
        end
        
        // Pack
        z[22 : 0] = z_m[22:0];
        z[30 : 23] = (z_e[7:0]) + 127;
        z[31] = z_s;
        if ($signed(z_e) == -126 && z_m[23] == 0) begin
          z[30 : 23] = 0;
        end
        //if overflow occurs, return inf
        if ($signed(z_e) > 127) begin
          z[22 : 0] = 0;
          z[30 : 23] = 255;
          z[31] = z_s;
        end
	end
	
    // Return 
    adder = z;
end
endfunction


function [31:0] int_to_float;
input 	[31:0]	a;
reg 	[31:0]	z, value;
reg		[23:0]	z_m;
reg		[7:0]	z_e, z_r;
reg				z_s;
reg				guard, round_bit, sticky;
reg				finish;

begin
	finish = 0;
// Convert 0
    if ( a == 0 ) begin
        z_s = 0;
        z_m = 0;
        z_e = -127;
        finish = 1;
    end else begin
        value = a[31] ? -a : a;
        z_s = a[31];
    end
    
	if (finish == 0) begin
    // Convert 1
        z_e = 31;
        z_m = value[31:8];
        z_r = value[7:0];
    
    // Convert 2
        repeat (30) begin
            if (z_m[23] == 0) begin
                z_e = z_e - 1;
                z_m = z_m << 1;
                z_m[0] = z_r[7];
                z_r = z_r << 1;
            end
        end
        guard = z_r[7];
        round_bit = z_r[6];
        sticky = z_r[5:0] != 0;
    
        // Round
        if (guard && (round_bit | sticky | z_m[0])) begin
          z_m = z_m + 1;
          if (z_m == 24'hffffff) begin
            z_e = z_e + 1;
          end
        end
    end
    // Pack
    z[22 : 0] = z_m[22:0];
    z[30 : 23] = z_e[7:0] + 127;
    z[31] = z_s;
    
    //if overflow occurs, return inf
    if ($signed(z_e) > 127) begin
        z[22 : 0] = 0;
        z[30 : 23] = 255;
        z[31] = z_s;
    end
	
    // Return 
    int_to_float = z;
end
endfunction


function [31:0] float_to_int;
input 	[31:0]	a;
reg 	[31:0]	a_m, a, z;
reg		[7:0]	a_e;
reg				a_s;
reg				finish;

begin
// Unpack
    a_m[31:8] = {1'b1, a[22 : 0]};
    a_m[7:0] = 0;
    a_e = a[30 : 23] - 127;
    a_s = a[31];

	finish = 0;
    // Special Cases
    
    if ($signed(a_e) == -127) begin
        z = 0;
        
        finish = 1;
    end else if ($signed(a_e) > 31) begin
        z = 32'h80000000;
        
        finish = 1;
    end

	if (finish == 0) begin
    // Convert
		repeat (20) begin
			if ($signed(a_e) < 31 && a_m) begin
				a_e = a_e + 1;
				a_m = a_m >> 1;
			end
			if (a_m[31]) begin
				z = 32'h80000000;
			end else begin
				z = a_s ? -a_m : a_m;
			end
		end
    end
	
    // Return 
    float_to_int = z;
end
endfunction


function greater_than;
input 	[31:0]	a;
input 	[31:0]	b;
reg 	    	z;
reg		[26:0]	a_m, b_m;
reg		[9:0]	a_e, b_e;
reg				a_s, b_s;
reg				finish;

begin
// Unpack
	a_m = {a[22 : 0], 3'd0};
	b_m = {b[22 : 0], 3'd0};
	a_e = a[30 : 23] - 127;
	b_e = b[30 : 23] - 127;
	a_s = a[31];
	b_s = b[31];

// Special Cases
	finish = 0;
    // if a is NaN or b is NaN return NaN 
	if ((a_e == 128 && a_m != 0) || (b_e == 128 && b_m != 0)) begin
		z = -1;
		
		finish = 1;
	//if a is inf or b is inf check the signal
	end else if ((a_e == 128) || (b_e == 128)) begin
	    if (a_s < b_s) begin
	        z = 1;
	    end else begin
	        z = 0;
	    end
	    
		finish = 1;
	//if a is zero return b
	end else if (($signed(a_e) == -127) && (a_m == 0)) begin
		if (b_s == 0) begin
	        z = 0;
	    end else begin
	        z = 1;
	    end

		finish = 1;
	//if b is zero return a
	end else if (($signed(b_e) == -127) && (b_m == 0)) begin
		if (a_s == 0) begin
	        z = 1;
	    end else begin
	        z = 0;
	    end
	    
		finish = 1;
	end else begin
		//Denormalised Number a
		if ($signed(a_e) == -127) begin
			a_e = -126;
		end else begin
			a_m[23] = 1;
		end
		// Denormalised Number b
		if ($signed(b_e) == -127) begin
			b_e = -126;
		end else begin
			b_m[23] = 1;
		end
	end
	
	
	if (finish == 0) begin
	
	    // Align
		repeat (20) begin
			if ($signed(a_e) != $signed(b_e))
			begin
				if ($signed(a_e) > $signed(b_e)) begin
					b_e = b_e + 1;
					b_m = b_m >> 1;
					b_m[0] = b_m[0] | b_m[1];
				end else if ($signed(a_e) < $signed(b_e)) begin
					a_e = a_e + 1;
					a_m = a_m >> 1;
					a_m[0] = a_m[0] | a_m[1];
				end
			end
		end
        
        // Compare
        if (a_s == b_s) begin
            if (a_s == 0) begin
                if (a_m > b_m) begin
                    z = 1;
                end else begin
                    z = 0;
                end
            end else begin
                if(a_m < b_m) begin
                    z = 0;
                end else begin
                    z = 1;
                end
            end
        end else begin
            if (a_s > b_s) begin
                z = 1;
            end else begin
                z = 0;
            end
        end
    end
    // Return 
    greater_than = z;
end
endfunction

endmodule