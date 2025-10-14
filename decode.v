//我还不知道是用时序逻辑还是组合逻辑
module decode(
    input                   clk,                    //时钟
    input                   rst_n,                  //复位信号
    input       [31:0]      command_byte,           //命令数据

    output      [1:0]       Sdram_index,            //读写SDRAM的索引       
    output reg  [1:0]       read_ch,                //读端口选择信号
    output reg  [1:0]       write_ch,               //写端口选择信号
    output      [31:0]      sd_card_bmp_read_addr,  //SD卡的读地址
);

wire [9:0]  SD_card_index;
wire [1:0]  SDRAM_index;
wire [3:0]  move_type;      //操作类型

assign move_type = command_byte[3:0];
assign SDRAM_index = command_byte[5:4];
assign SD_card_index = command_byte[15:6];
assign sd_card_bmp_read_addr = (SD_card_index - 1)*1800 + 8484;

always@(*)begin
    case(move_type)
    4'd0:begin      //默认空类型
        read_ch = 2'd0;
        write_ch = 2'd0;
    end
    4'd1:begin      //camera ---> sdram
        read_ch = 2'd0;
        write_ch = 2'd1;
    end
    4'd2:begin      //sdcard ---> sdram
        read_ch = 2'd0;
        write_ch = 2'd2;
    end
    // 4'd3:begin      //sdram ---> hdmi //这个还不需要
    // end
    default:begin
        read_ch = 2'd0;
        write_ch = 2'd0;
    end
    endcase
end


endmodule 