`timescale 1 ns/1 ns
`include "./clock.v"
`include "./BCDv2.v"
module DPA_Cyuan (clk,reset,IM_A, IM_Q,IM_D,IM_WEN,CR_A,CR_Q);
input clk;
input reset;
output reg [19:0] IM_A;
input      [23:0] IM_Q;
output reg [23:0] IM_D;
output reg        IM_WEN;
output reg [8:0]  CR_A;
input      [12:0] CR_Q;
//up don't modify, start from down


reg   [23:0] init_time, FB_addr, photo_num;
reg   [23:0] p1_addr, p1_size, p2_addr, p2_size, p3_addr, p3_size,p4_addr, p4_size;
reg   [1:0]  global_state_r, global_state;
reg          readheader, dealtime, dealphoto;
wire  [4:0]  sec_count; // sec th(number of sec)

//later put down
wire        time_finish;
reg  [19:0] rd_char_addr;
reg  [4:0]  cnt_wrchar_row;
reg  [3:0]  cnt_wait_wr;
reg  [3:0]  cnt_readheader;
reg  [7:0]  time_out;
//wire [3:0]  one, ten, char_num, ;
reg[3:0]num_colon_sel;
reg  [8:0]  char_start_addr;

wire [7:0]  hr, min, sec;
reg  [2:0]  wrchar_state, wrchar_state_r;

reg  [3:0]  cnt_char; //cnt to 8 means all char done
reg  [4:0]  cnt_char_row;// cnt to 24 means one char done
reg  [3:0]  cnt_time_pixel;//cnt to 13 means one row done
reg  [19:0] im_a_char;//IM_A from char
wire [23:0] im_d_char;//IM_D from char
wire        next_row;
reg[1:0]rdchar_state_r;
reg[1:0]rdchar_state;
wire [19:0]time_start_addr;
assign time_start_addr = FB_addr + 24'd59544;
parameter CLK_STARTADDR = 3'd1, WRCHARAD1 = 3'd2, WRCHARAD0 = 3'd3,
WRCHARAD244 = 3'd4, WRCHARMINUS6143 = 3'd5, WRCHARDONE = 3'd6;
reg rd_en_512, wr_en_512, tran_part1, tran_part2, wr_chose;
reg [19:0] rd_addr_512, wr_addr_512; 
reg[23:0] rgb_in0, rgb_in1, rgb_in2, rgb_in3;
//assign IM_A = cnt_readheader;

//read header
always@(negedge clk or posedge reset)begin
    if (reset)begin
       {init_time, FB_addr, photo_num,
        p1_addr, p1_size, p2_addr, p2_size,
        p3_addr, p3_size, p4_addr, p4_size} <= 264'd0;
    end
    else if(readheader)begin
        init_time <= FB_addr;
        FB_addr <= photo_num;
        photo_num <= p1_addr;
        p1_addr <= p1_size;
        p1_size <= p2_addr;
        p2_addr <= p2_size;
        p2_size <= p3_addr;
        p3_addr <= p3_size;
        p3_size <= p4_addr;
        p4_addr <= p4_size;
        p4_size <= IM_Q;
        // below 往前推一格
    end
    else begin
        init_time <= init_time;
        FB_addr <= FB_addr;
        photo_num <= photo_num;
        p1_addr <= p1_addr;
        p1_size <= p1_size;
        p2_addr <= p2_addr;
        p2_size <= p2_size;
        p3_addr <= p3_addr;
        p3_size <= p3_size;
        p4_addr <= p4_addr;
        p4_size <= p4_size;
    end
end

//counter for readheader
always @(negedge clk or posedge reset)begin
    if(reset)
        cnt_readheader <= 4'd0;
    else if(readheader)
        cnt_readheader <= cnt_readheader + 1'd1;
    else
        cnt_readheader <= cnt_readheader;
end

//top fsm
parameter ReadHeader = 2'd1, DealTime = 2'd2, DealPhoto = 2'd3;
always @(negedge clk or posedge reset) begin
    if(reset)
        global_state_r <= 2'd0;
    else
        global_state_r <= global_state;
end

//tran
always @(*) begin
    case(global_state_r)
    2'd0:
        global_state = ReadHeader;

    ReadHeader:begin
        if(cnt_readheader == 4'd11)//don't change
            global_state = DealTime;
        else
            global_state = ReadHeader;
    end
    DealTime:begin
        if(time_finish && (sec_count[0] == 1'd0))// only when even second will do photo
            global_state = DealPhoto;
        else
            global_state = DealTime;//improve
    end
    DealPhoto:begin
        if(time_finish)
            global_state = DealPhoto;
        else 
            global_state = DealTime;
    end
    default:
        global_state = 2'd0;
    endcase
end

//output
always @(*) begin
    case(global_state_r)
    2'd0:begin
        readheader = 1'd0;
        dealtime = 1'd0;
        dealphoto = 1'd0;
    end
    ReadHeader:begin
        readheader = 1'd1;
        dealtime = 1'd0;
        dealphoto = 1'd0;
    end
    DealTime:begin
        readheader = 1'd0;
        dealtime = 1'd1;
        dealphoto = 1'd0;
    end
    DealPhoto:begin
        readheader = 1'd0;
        dealtime = 1'd0;
        dealphoto = 1'd1;
    end
    default:begin
        readheader = 1'd0;
        dealtime = 1'd0;
        dealphoto = 1'd0;
    end
    endcase
end

//IM_A control
always @(negedge clk or posedge reset) begin
    if(reset)
        IM_A <= 20'd0;
    else if(readheader)
        IM_A <= cnt_readheader;
    else if(dealtime)/////////////modify
        case(wrchar_state_r)
        3'd0:begin
            IM_A <= 20'd0;
        end
        CLK_STARTADDR:begin
            IM_A <= time_start_addr;
        end
        WRCHARAD1:begin
            IM_A <= IM_A + 1;
        end
        WRCHARAD0:begin
            IM_A <= IM_A;
        end
        WRCHARAD244:begin
            IM_A <= IM_A + 24'd244;
        end
        WRCHARMINUS6143:begin
            IM_A <= IM_A - 24'd5887;
        end
        WRCHARDONE:begin
            IM_A <= IM_A;
        end
        //3'd7:IM_A <= IM_A;
        default:begin
            IM_A <= IM_A;
        end
        endcase
	else if(dealphoto)
		if(wr_addr_256 == FB_addr + 20'd65430)
			if(rd_en_256)
				begin
					tran_part1 <= 0;
					tran_part2 <= 1;
					IM_A <= p1_addr;
				end
			else if(~ rd_en_256)
				begin
					tran_part1 <= 0;
					tran_part2 <= 1;
					IM_A <= p1_addr;
				end
			else 
				begin
					tran_part1 <= tran_part1;
					tran_part2 <= tran_part2;
					IM_A <= IM_A;
				end
		else
			if(rd_en_256)
				begin
					tran_part1 <= 1;
					tran_part2 <= 0;
					IM_A <= p1_addr;
				end
			else if(~ rd_en_256)
				begin
					tran_part1 <= 1;
					tran_part2 <= 0;
					IM_A <= p1_addr;
				end
			else 
				begin
					tran_part1 <= tran_part1;
					tran_part2 <= tran_part2;
					IM_A <= IM_A;
				end
	else 
        IM_A <= 20'd0;
end 
	
//512to256---------------------------------------(DIDNT WRITE HOW TO STOP) Cyuan fixed ver
reg[3:0] crd_state_512, nrd_state_512, cwr_state_512, nwr_state_512;
reg [4:0] rd_cnt_512, wr_cnt_512;
reg [7:0] rd_cntb_512, wr_cntb_512, row_rd_cnt_512, row_wr_cnt_512;
reg [18:0] c,d;

//fsm
always@(negedge clk or posedge reset)
	begin
	if(reset)
		begin
			crd_state_512 <= 0;
			cwr_state_512 <= 0;
		end
	else if(dealphoto)
		begin
		crd_state_512 <= nrd_state_512;
		cwr_state_512 <= nwr_state_512;		
		end
	else
		begin
			crd_state_512 <= crd_state_512;
			cwr_state_512 <= cwr_state_512;
		end
	end
//rd

always@(*)
	begin
	if(dealphoto)
		case(crd_state_512)
		4'd0://CHOOSE PART1 OR PART2
			begin
				if(~wr_en_512)
					if(tran_part1)
						nrd_state_512 = 4'd1;
					else if(tran_part2)
						nrd_state_512 = 4'd2;
					else
						nrd_state_512 = 4'd0;
				else
					nrd_state_512 = 4'd0;
			end
		4'd1://START +2 STATE(PART1)
			begin
				c = start_addr;/*pic_512的起始位置，先給c*/
				rd_addr_512 = c + 2;
				c += 2; 
				nrd_state_512 = 4'd3;
			end
		4'd2://START +0 STATE(PART2)
			begin
				c = start_addr;
				rd_addr_512 = c;
				nrd_state_512 = 4'd3;
			end
		4'd3://FIRST +1 STATE
			begin
				rd_addr_512 = c + 1;
				c += 1;
				nrd_state_512 = 4'd4;
			end
		4'd4://THE +511 STATE 
			begin
				rd_addr_512 = c + 511;
				c += 511; 
				nrd_state_512 = 4'd5;
			end
		4'd5://SECOND +1 STATE
			begin
				rd_addr_512 = c + 1;
				c += 1;
				rd_cntb_512 = rd_cntb_512 + 1;
				nrd_state_512 = 4'd6;
				rd_en_512 = 1'd0;
				wr_en_512 = 1'd1;
			end
		4'd6://THE +0 STATE 
			begin
				if(wr_addr_512 == FB_addr + 20'd65430)
					nrd_state_512 = 4'd0;
				else
					rd_addr_512 = c;
					 if(wr_en_512)//----------------------------------------------------------------wr_en_512
						begin
						if(tran_part1)
							begin
							if((row_rd_cnt_512[0])/*奇數行*/ && (rd_cntb_512 == 75) && (row_rd_cnt_512 >= 231))
								nrd_state_512 = 4'd11;
							else if((~ row_rd_cnt_512[0])/*偶數行*/ && (rd_cntb_512 == 75) && (row_rd_cnt_512 >= 231))
								nrd_state_512 = 4'd10;
							else if((row_rd_cnt_512[0])/*奇數行*/ && (rd_cntb_512 == 255) && (row_rd_cnt_512 < 231))
								nrd_state_512 = 4'd9;
							else if((~ row_rd_cnt_512[0])/*偶數行*/ && (rd_cntb_512 == 255) && (row_rd_cnt_512 < 231))
								nrd_state_512 = 4'd8;
							else if((~ (rd_cntb_512 == 75)/*一列還沒讀完*/ && (row_rd_cnt_512 >= 231)) || (~ (rd_cntb_512 == 255)/*一列還沒讀完*/ && (row_rd_cnt_512 < 231)))
								nrd_state_512 = 4'd7;
							else
								nrd_state_512 = 4'd6;
							end
						else if(tran_part2)
							begin
							if((row_rd_cnt_512[0]) && (rd_cntb_512 == 75) && (row_rd_cnt_512 >= 231))
								nrd_state_512 = 4'd10;
							else if((~ row_rd_cnt_512[0]) && (rd_cntb_512 == 75) && (row_rd_cnt_512 >= 231))
								nrd_state_512 = 4'd11;
							else if((row_rd_cnt_512[0]) && (rd_cntb_512 == 255) && (row_rd_cnt_512 < 231))
								nrd_state_512 = 4'd8;
							else if((~ row_rd_cnt_512[0]) && (rd_cntb_512 == 255) && (row_rd_cnt_512 < 231))
								nrd_state_512 = 4'd9;
							else //if((~ (rd_cntb_512 == 75) && (row_rd_cnt_512 >= 231)) || (~ (rd_cntb_512 == 255) && (row_rd_cnt_512 < 231)))
								nrd_state_512 = 4'd7;
							else
								nrd_state_512 = 4'd6;
							end
						else
							nrd_state_512 = 4'd6;
						end
					else
							nrd_state_512 = 4'd6;
			end
		4'd7://THE -509 STATE  做下一個block
			begin
				rd_en_512 = 1'd1;
				rd_addr_512 = c - 509;
				c = c - 509;
				nrd_state_512 = 4'd3;
			end
		4'd8://THE CHANGE ROW +1 STATE
			begin
				rd_en_512 = 1'd1;
				rd_addr_512 = c + 1;
				c += 1;
				nrd_state_512 = 4'd3;
				row_rd_cnt_512 = row_rd_cnt_512 + 1;
			end
		4'd9://THE CHANGE ROW +5 STATE
			begin
				rd_en_512 = 1'd1;
				rd_addr_512 = c + 5;
				c = c + 5;
				nrd_state_512 = 4'd3;
				row_rd_cnt_512 = row_rd_cnt_512 + 1;
			end
		4'd10://THE CHANGE ROW +105 STATE
			begin
				rd_en_512 = 1'd1;
				rd_addr_512 = c + 105;
				c = c + 105;
				nrd_state_512 = 4'd3;
				row_rd_cnt_512 = row_rd_cnt_512 + 1;
			end
		4'd11://THE CHANGE ROW +109 STATE
			begin
				rd_en_512 = 1'd1;
				rd_addr_512 = c + 109;
				c = c + 109;
				nrd_state_512 = 4'd3;
				row_rd_cnt_512 = row_rd_cnt_512 + 1;
			end
		endcase
	else
		nrd_state_512 = crd_state_512;
	end
//wr
always@(*)
	begin
		case(cwr_state_512)
		4'd0://CHOOSE PART1 OR PART2
			begin
				if(wr_en_512)
					if(tran_part1)
						nwr_state_512 = 4'd1;
					else if(tran_part2)
						nwr_state_512 = 4'd2;
					else
						nwr_state_512 = cwr_state_512;
				else
					nwr_state_512 = 4'd0;
			end
		4'd1://START +1 STATE(PART1)
			begin
				d = start_addr;
				wr_addr_512 = d + 1;//frame_buffer 的位置
				d = d + 1;
				nwr_state_512 = 4'd3;
			end
		4'd2://START +0 STATE(PART2)
			begin
				d = start_addr;
				wr_addr_512 = d;
				nwr_state_512 = 4'd3;
			end
		4'd3://THE +0 STATE
			begin
				if(wr_en_512)
					if(tran_part1)
						if((~ row_wr_cnt_512[0])/*偶數列*/ && (wr_cntb_512 == 127) && (row_wr_cnt_512 < 231))
							nwr_state_256 = 4'd5;
						else if((row_wr_cnt_512[0])/*奇數列*/ && (wr_cntb_512 == 127) && (row_wr_cnt_512 < 231))
							nwr_state_512 = 4'd6;
						else if((~ row_wr_cnt_512[0])/*偶數列*/ && (wr_cntb_512 == 75) && (row_wr_cnt_512 >= 231))
							nwr_state_512 = 4'd7;
						else if((row_wr_cnt_512[0])/*奇數列*/ && (wr_cntb_512 == 75) && (row_wr_cnt_512 >= 231))
							nwr_state_512 = 4'd8;
						else
							nwr_state_512 = 4'd4;
					else if(tran_part2)
						if((~ row_wr_cnt_512[0])/*偶數列*/ && (wr_cntb_512 == 31) && (row_wr_cnt_512 < 231))
							nwr_state_512 = 4'd5;
						else if((row_wr_cnt_512[0])/*奇數列*/ && (wr_cntb_512 == 31) && (row_wr_cnt_512 < 231))
							nwr_state_512 = 4'd6;
						else if((~ row_wr_cnt_512[0])/*偶數列*/ && (wr_cntb_512 == 18) && (row_wr_cnt_512 >= 231))
							nwr_state_512 = 4'd7;
						else if((row_wr_cnt_512[0])/*奇數列*/ && (wr_cntb_512 == 18) && (row_wr_cnt_512 >= 231))
							nwr_state_512 = 4'd8;
						else								
							nwr_state_512 = 4'd4;
					else
						nwr_state_512 = 4'd3;
				else
						nwr_state_512 = 4'd3;
			end
		4'd4://THE +2 STATE
			begin
				/*寫數值進去FB_address*/
				wr_addr_512 = wr_addr_512 + 2;
				wr_cntb_512 = wr_cntb_512 + 1;
				nwr_state_512 = 4'd3;
				rd_en_512 = 1'd1;
				wr_en_512 = 1'd0;
			end
		4'd5://THE CHANGE ROW +1 STATE
			begin
				/*寫數值進去FB_address*/
				wr_addr_512 = wr_addr_512 + 1;
				wr_cntb_512 = 0;
				row_wr_cnt_512 = row_wr_cnt_512 + 1;
				nwr_state_512 = 4'd3;
				rd_en_512 = 1'd1;
				wr_en_512 = 1'd0;
			end
		4'd6://THE CHANGE ROW +3 STATE
			begin
				/*寫數值進去FB_address*/
				wr_addr_512 = wr_addr_512 + 3;
				wr_cntb_512 = 0;
				row_wr_cnt_512 = row_wr_cnt_512 + 1;
				nwr_state_512 = 4'd3;
				rd_en_512 = 1'd1;
				wr_en_512 = 1'd0;
			end
		4'd7://THE CHANGE ROW +105 STATE
			begin
				/*寫數值進去FB_address*/
				wr_addr_512 = wr_addr_512 + 105;
				wr_cntb_512 = 0;
				row_wr_cnt_512 = row_wr_cnt_512 + 1;
				nwr_state_512 = 4'd3;
				rd_en_512 = 1'd1;
				wr_en_512 = 1'd0;
			end
		4'd8://THE CHANGE ROW +107 STATE
			begin
				/*寫數值進去FB_address*/
				wr_addr_512 = wr_addr_512 + 107;
				wr_cntb_512 = 0;
				row_wr_cnt_512 = row_wr_cnt_512 + 1;
				nwr_state_512 = 4'd3;
				rd_en_512 = 1'd1;
				wr_en_512 = 1'd0;
			end
		default://STAND STILL
			begin
				wr_addr_512 = wr_addr_512;
				wr_cntb_512 = wr_cntb_512;
				row_wr_cnt_512 = row_wr_cnt_512;
				nwr_state_512 = cwr_state_512;
			end
		endcase
	end




//IM_WEN control
always @(negedge clk or posedge reset) begin
    if(reset)
        IM_WEN <= 1'd1;
    else if(dealtime)
        IM_WEN <= 1'd0;
	else if(dealphoto)
        IM_WEN <= 1'd1;
    else////////////////////////////////////modify
        IM_WEN <= 1'd1;

end

//IM_D control
always @(negedge clk or posedge reset) begin
    if(reset)
        IM_D <= 24'd0;
    else if(dealtime)
        IM_D <= im_d_char;
    else if(dealphoto)
		IM_D <= rgb_in0;
	else
		IM_D <= 24'd0;
end
//////////////////////////////deal time///////////////////////////
//main, i don't know where to put this, but it's important
wire[3:0]hr_ten, min_ten, sec_ten, hr_one, min_one, sec_one;
clock clocku0(.reset(reset), .clk(clk), .init_time(init_time), .hr_r(hr), .min_r(min), .sec_r(sec), .sec_count(sec_count));
BCDv2 BCDv2u0(.A(hr),  .ONE(hr_one),  .TEN(hr_ten));
BCDv2 BCDv2u1(.A(min), .ONE(min_one), .TEN(min_ten));
BCDv2 BCDv2u2(.A(sec), .ONE(sec_one), .TEN(sec_ten));

reg[3:0]char_state_r;
reg[3:0]char_state;
always @(negedge clk or posedge reset) begin
    if(reset)
        char_state_r <=  4'd0;
    else 
        char_state_r <= char_state;
end

//mux to choose char start addr(0~9: total 11)
always @(*) begin
    case(num_colon_sel)
        4'd0: char_start_addr = 9'd0;
        4'd1: char_start_addr = 9'd24;
        4'd2: char_start_addr = 9'd48;
        4'd3: char_start_addr = 9'd72;
        4'd4: char_start_addr = 9'd96;
        4'd5: char_start_addr = 9'd120;
        4'd6: char_start_addr = 9'd144;
        4'd7: char_start_addr = 9'd168;
        4'd8: char_start_addr = 9'd192;
        4'd9: char_start_addr = 9'd216;
        4'd10: char_start_addr = 9'd240;
        default: char_start_addr = 9'd0;
    endcase
end

parameter Hrten = 4'd1, Hrone = 4'd2, 
Minten = 4'd3, Minone = 4'd4, 
Secten = 4'd5, Secone = 4'd6, 
Colon1 = 4'd7, Colon2 = 4'd8;

always @(*) begin
    case(char_state_r)
    4'd0:num_colon_sel = 4'd0;
    Hrten:num_colon_sel = hr_ten;
    Hrone:num_colon_sel = hr_one;
    Minten:num_colon_sel = min_ten;
    Minone:num_colon_sel = min_one;
    Secten:num_colon_sel = sec_ten;
    Secone:num_colon_sel = sec_one;
    Colon1:num_colon_sel = 4'd10;
    Colon2:num_colon_sel = 4'd10;
    default:num_colon_sel = 4'd0;
    endcase
end




always @(*) begin
    case(char_state_r)
    4'd0:
        char_state = Hrten;
    Hrten:
        if(cnt_wrchar_row ==5'd22 && rdchar_state_r == 3)
            char_state = Hrone;
        else
            char_state = Hrten;
    Hrone:
        if(cnt_wrchar_row ==5'd22 && rdchar_state_r == 3)
            char_state = Colon1;
        else
            char_state = Hrone;
    Colon1:
        if(cnt_wrchar_row ==5'd22 && rdchar_state_r == 3)
            char_state = Minten;
        else
            char_state = Colon1;
    Minten:
        if(cnt_wrchar_row ==5'd22 && rdchar_state_r == 3)
            char_state = Minone;
        else
            char_state = Minten;
    Minone:
        if(cnt_wrchar_row ==5'd22 && rdchar_state_r == 3)
            char_state = Colon2;
        else
            char_state = Minone;
    Colon2:
        if(cnt_wrchar_row ==5'd22 && rdchar_state_r == 3)
            char_state = Secten;
        else
            char_state = Colon2;        
    Secten:
        if(cnt_wrchar_row ==5'd22 && rdchar_state_r == 3)
            char_state = Secone;
        else
            char_state = Secten;
    Secone:
        if(cnt_wrchar_row ==5'd22 && rdchar_state_r == 3)
            char_state = Secone;
        else
            char_state = Secone;
    default:
        char_state = Hrten;
    endcase
end

//rd char fsm seq
parameter Rdchar_start = 2'd1, Rdchar_ad0 = 2'd2, Rdchar_ad1 = 2'd3;
always @(negedge clk or posedge reset) begin
    if (reset)
        rdchar_state_r <= 2'd0;
    else
        rdchar_state_r <= rdchar_state;
end

//trans
always @(*) begin
    case(rdchar_state_r)
    2'd0: 
        rdchar_state = (dealtime)?Rdchar_start:2'd0;
    Rdchar_start: 
        rdchar_state = Rdchar_ad0;
    Rdchar_ad0:
        if(cnt_wrchar_row == 5'd23 && cnt_wait_wr==12)
            rdchar_state = Rdchar_start;
        else if(cnt_wait_wr==12)
            rdchar_state = Rdchar_ad1;
        else
            rdchar_state = Rdchar_ad0;
    Rdchar_ad1:
        if(cnt_wrchar_row == 5'd23)
            rdchar_state = Rdchar_start;
        else
            rdchar_state= Rdchar_ad0;
    default: rdchar_state = 2'd0;
	endcase
end

// output
always @(negedge clk or posedge reset) begin
    if(reset)begin
        CR_A <= 9'd0;
        cnt_wrchar_row <= 5'd0;
        cnt_wait_wr <=4'd0;
        end
    else
    case(rdchar_state_r)
        2'd0:begin
            CR_A <= 9'd0;
            cnt_wait_wr <= 4'd0;
            cnt_wrchar_row <= 5'd0;
            end
        Rdchar_start:begin
            CR_A <= char_start_addr;
            cnt_wait_wr <= 4'd0;
            cnt_wrchar_row <=5'd0;
        end
        Rdchar_ad0:begin
            CR_A <= CR_A;
            cnt_wait_wr <= cnt_wait_wr + 4'd1;
            cnt_wrchar_row <=cnt_wrchar_row;
        end
        Rdchar_ad1:begin
            CR_A <= CR_A + 9'd1;
           cnt_wait_wr <= 4'd0;
            cnt_wrchar_row <=cnt_wrchar_row + 5'd1;
        end
        default:begin
            CR_A <= CR_A;
           cnt_wait_wr <= cnt_wait_wr;
            cnt_wrchar_row <=cnt_wrchar_row;
        end
    endcase
end

//CHAR_in
reg[12:0] char_row;
always @(negedge clk or posedge reset) begin
    if(reset)
        char_row <= 13'd0;
    else if(wrchar_state_r == 3)/////MOD
        char_row <= CR_Q;      
    else
        char_row <= char_row<<1'd1;
end

//RGB_in
/*假設已經取好一個block的數值(4個)*/
reg[23:0] rgb0, rgb1, rgb2, rgb3, rgbnew;
always@(negedge clk or posedge reset)
begin
	if(reset)
		{rgb_in0, rgb_in1, rgb_in2, rgb_in3} <= 96'd0;
	else if(dealphoto && wr_en_512 == 1)
		begin
			rgbnew[23:16] = ( rgb0[23:16] + rgb1[23:16] + rgb2[23:16] )/4;
			rgbnew[15:8] = ( rgb0[15:8] + rgb1[15:8] + rgb2[15:8] )/4;
			rgbnew[7:0] = ( rgb0[7:0] + rgb1[7:0] + rgb2[7:0] )/4;
			IM_Q = rgbnew; 
		end
	else
		begin
			rgb0 = rgb0;
			rgb1 = rgb1;
			rgb2 = rgb2;
			rgb3 = rgb3;
		end
end

//IM_D
assign im_d_char = (char_row[12]) ? 24'hffffff:24'd0;

//IM_A
always @(negedge clk or posedge reset) begin
   if(reset)
       wrchar_state_r <= 0;
   else
       wrchar_state_r <= wrchar_state;
end
//tran
always @(*) begin
    case(wrchar_state_r)
    3'd0:
        wrchar_state = (dealtime && (cnt_char_row ==0) && (rdchar_state_r == 3)) ? CLK_STARTADDR : 3'd0;
    CLK_STARTADDR:
        wrchar_state = WRCHARAD1;
    WRCHARAD1:
        wrchar_state = (cnt_time_pixel==12) ? WRCHARAD0: WRCHARAD1;
    WRCHARAD0:
        if((cnt_char ==7) && (cnt_char_row == 23) )
            wrchar_state = WRCHARDONE;
        else if(cnt_char_row ==23)
           wrchar_state = WRCHARMINUS6143;
        else 
            wrchar_state = WRCHARAD244;
    WRCHARAD244:
        wrchar_state = WRCHARAD1;
    WRCHARMINUS6143:
        wrchar_state = (cnt_char == 7)?WRCHARDONE:WRCHARAD1;
    WRCHARDONE:
        wrchar_state = WRCHARDONE;
    default:
        wrchar_state = 0;
    endcase
end


always @(negedge clk or posedge reset) begin
    if(reset)begin
        //im_a_char <= 20'd0;
        cnt_time_pixel <= 4'd0;
        cnt_char <= 4'd0;
        cnt_char_row <= 5'd0;
    end
    else
        case(wrchar_state_r)
        3'd0:begin
            //im_a_char <= 20'd0;
            cnt_time_pixel <= 4'd0;
            cnt_char <= 4'd0;
            cnt_char_row <= 5'd0;
        end
        CLK_STARTADDR:begin
            //im_a_char <= time_start_addr;
            cnt_time_pixel <= cnt_time_pixel + 4'd1;
            cnt_char <= cnt_char;
            cnt_char_row <= cnt_char_row;
        end
        WRCHARAD1:begin
            //im_a_char <= im_a_char + 1;//strange
            cnt_time_pixel <= cnt_time_pixel + 4'd1;
            cnt_char <= cnt_char;
            cnt_char_row <= cnt_char_row;
        end
        WRCHARAD0:begin
            //im_a_char <= im_a_char -1;//strange
            cnt_time_pixel <= 4'd0;
            cnt_char <= cnt_char;
            cnt_char_row <= cnt_char_row;
        end
        WRCHARAD244:begin
            //im_a_char <= im_a_char + 24'd245;
            cnt_time_pixel <= cnt_time_pixel + 4'd1;
            cnt_char <= cnt_char;
            cnt_char_row <= cnt_char_row+1;
        end
        WRCHARMINUS6143:begin
            //im_a_char <= im_a_char - 24'd6143;
            cnt_time_pixel <= cnt_time_pixel + 4'd1;
            cnt_char_row <= 0;
            cnt_char <= cnt_char +1;
        end
        WRCHARDONE:begin
            //im_a_char <= im_a_char;
            cnt_time_pixel <= cnt_time_pixel;
            cnt_char <= cnt_char;
            cnt_char_row <= cnt_char_row;
        end
        default:begin
            //im_a_char <= im_a_char;
            cnt_time_pixel <= cnt_time_pixel;
            cnt_char <= cnt_char;
            cnt_char_row <= cnt_char_row;
        end
        endcase
    end



//assign next_row = (wrchar_state_r == WRCHARAD0) ? 1'd1 : 1'd0;
assign time_finish = (wrchar_state_r == WRCHARDONE) ? 1'd1 : 1'd0;

/*
//////////////////////deal photo////////////////////
//
wire[23:0]photo_size, photo_adddr;
always @(*) begin
    case(photo_cnt)
    2'd0:begin
        photo_size <= p1_size;
        photo_adddr <= p1_addr;
    end
    2'd1:begin
        photo_size <= p2_size;
        photo_adddr <= p2_addr;
    end
    2'd2:begin
        photo_size <= p3_size;
        photo_adddr <= p3_addr;
    end
    2'd3:begin
        photo_size <= p4_size;
        photo_adddr <= p4_addr;
    end
    default:begin
        photo_size <= p1_size;
        photo_adddr <= p1_addr;
    end

end

//photo cnt
always @(posedge clk or posedge reset) begin
    if(reset)
        photo_cnt<= 0;
    else if(sec_count[0]==0)
        photo_cnt <= photo_cnt +1;
    else if(photo_cnt = photo_num)
        photo_cnt <=0;
    else
        photo_cnt <= photo_cnt;
end


reg[23:0] reg0,reg1,reg2,reg3;
always @(posedge clk or posedge reset) begin
    if(reset)
        {reg0,reg1,reg2,reg3} <= 96'd0;
    else
        reg0 <=reg1;
        reg1 <= reg2;
        reg2 <= reg3;
        reg3 <= IM_Q;

end

//rd photo addr
always @(posedge clk or posedge reset) begin
    if(reset)
        rd_photo_state_r <= 0;
    else
        rd_photo_state_r <= rd_photo_state;
end

parameter Rdphoto_start_tran1 = 3'd1, Rdphoto_start_tran2 = 3'd2,
Rdphoto_ad2 = 3'd3, Rdphoto_ad0 = 3'd4,
Rdphoto_ad1 = 3'd5, Rdphoto_ad3 = 3'd6;

always @(*) begin
    case(rd_photo_state_r)
    3'd0:if(tranpart1 && (photo_size == 256))
            rd_photo_state = Rdphoto_start_tran1;
        else if(tranpart2 && (photo_size == 256))
            rd_photo_state = Rdphoto_start_tran2;
        else
            rd_photo_state = 3'd0;

    Rdphoto_start_tran1:
        rd_photo_state = Rdphoto_ad2;
    Rdphoto_start_tran2:
        rd_photo_state = Rdphoto_ad2;
    Rdphoto_ad2:
        rd_photo_state = (cnt_ad2 == 4)?Rdphoto_ad0:Rdphoto_ad2;
    Rdphoto_ad0:
        if(cnt_wait_wr == 4)
            rd_photo_state = Rdphoto_ad2;
        else begin
            rd_photo_state = (
            (tranpart1 && (!cnt_photo_row[0]) && cnt_block == 64) ||
            (tranpart2 &&  (cnt_photo_row[0]) && cnt_block == 64) ||
            (tranpart1 && (!cnt_photo_row[0]) && cnt_row >= 231 && cnt_block==38) ||
            (tranpart2 &&  (cnt_photo_row[0]) && cnt_row >= 231 && cnt_block==38))?
            Rdphoto_ad1:Rdphoto_ad3;
        end
    Rdphoto_ad1:
        rd_photo_state = Rdphoto_ad2;
    Rdphoto_ad3:
        rd_photo_state = Rdphoto_ad2;
    default:
        rd_photo_state = 3'd0;
end

always @(*) begin
    case(rd_photo_state_r)
    3'd0:begin
        cnt_ad2 = 0;
    end

    Rdphoto_start_tran1:begin
        rdphoto_addr = photo_adddr +1;
        cnt_ad2 = cnt_ad2+1;
    end
    Rdphoto_start_tran2:begin
        rdphoto_addr = photo_adddr;
        cnt_ad2 = cnt_ad2+1;
    end
    Rdphoto_ad2:begin
        rdphoto_addr = rdphoto_addr +2;
        cnt_ad2 = cnt_ad2+1;
        cnt_wait_wr = 0;
    end
    Rdphoto_ad0:begin
        rdphoto_addr = rdphoto_addr;
        cnt_wait_wr = cnt_wait_wr +1;
        cnt_block = cnt_block +1;
    end
    Rdphoto_ad1:begin
        rdphoto_addr = rdphoto_addr +1;
        cnt_photo_row = cnt_photo_row +1;
        cnt_block = 0;
        cnt_ad2 = cnt_ad2 +1;
    end
    Rdphoto_ad3:begin
        rdphoto_addr = rdphoto_addr +3;
        cnt_photo_row = cnt_photo_row +1;
        cnt_block = 0;
        cnt_ad2 = cnt_ad2 +1;
    end
end








reg[2:0]wrphoto_state_r,wrphoto_state;
//write photo addr
always @(posedge clk or posedge reset) begin
    if(reset)
        wrphoto_state_r <= 0;
    else
        wrphoto_state_r <= wrphoto_state;
end


parameter Wrphoto_start_tran1 = 3'd1, Wrphoto_start_tran2 = 3'd2,
Wrphoto_ad2 = 3'd3, Wrphoto_ad0 = 3'd4,
Wrphoto_ad1 = 3'd5, Wrphoto_ad3 = 3'd6;

always @(*) begin
    case(wrphoto_state_r)
    3'd0:if    (tranpart1 && (photo_size == 256) && (|cnt_wait_wr))
            wrphoto_state = Wrphoto_start_tran1;
        else if(tranpart2 && (photo_size == 256) && (|cnt_wait_wr))
            wrphoto_state = Wrphoto_start_tran2;
        else
            wrphoto_state = 3'd0;

    Wrphoto_start_tran1:
        wrphoto_state = Wrphoto_ad2;
   Wrphoto_start_tran2:
        wrphoto_state = Wrphoto_ad2;
    Wrphoto_ad2:
        wrphoto_state = (cnt_ad2 == 4)?Wrphoto_ad0:Wrphoto_ad2;
    Wrphoto_ad0:
        if(cnt_wait_rd == 4)
            wrphoto_state = Wrphoto_ad2;
        else begin
            wrphoto_state = (
            (tranpart1 && (!cnt_photo_row[0]) && cnt_block == 64) ||
            (tranpart2 &&  (cnt_photo_row[0]) && cnt_block == 64) ||
            (tranpart1 && (!cnt_photo_row[0]) && cnt_row >= 231 && cnt_block==38) ||
            (tranpart2 &&  (cnt_photo_row[0]) && cnt_row >= 231 && cnt_block==38))?
            Wrphoto_ad1:Wrphoto_ad3;
        end
    Wrphoto_ad1:
        wrphoto_state = Wrphoto_ad2;
    Wrphoto_ad3:
        wrphoto_state = Wrphoto_ad2;
    default:
        wrphoto_state = 3'd0;
end

always @(*) begin
    case(wrphoto_state_r)
    3'd0:begin
        cnt_ad2 = 0;
    end

    Wrphoto_start_tran1:begin
        wrphoto_addr = photo_adddr +1;
        cnt_ad2 = cnt_ad2+1;
    end
    Wrphoto_start_tran2:begin
        wrphoto_addr = photo_adddr;
        cnt_ad2 = cnt_ad2+1;
    end
    Rdphoto_ad2:begin
        wrphoto_addr = wrphoto_addr +2;
        cnt_ad2 = cnt_ad2+1;
        cnt_wait_rd = 0;
    end
    Wrphoto_ad0:begin
        wrphoto_addr = wrphoto_addr;
        cnt_wait_rd = cnt_wait_rd +1;
        cnt_block = cnt_block +1;
    end
    Wrphoto_ad1:begin
        wrphoto_addr = wrphoto_addr +1;
        cnt_photo_row = cnt_photo_row +1;
        cnt_block = 0;
        cnt_ad2 = cnt_ad2 +1;
    end
    Wrphoto_ad3:begin
        wrphoto_addr = wrphoto_addr +3;
        cnt_photo_row = cnt_photo_row +1;
        cnt_block = 0;
        cnt_ad2 = cnt_ad2 +1;
    end
end
*/




endmodule

