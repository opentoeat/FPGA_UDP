module top_ctrl(
input                                 udp_rx_clk              ,
input  wire                           reset                   ,

input                                 app_rx_data_valid       ,
input                      [7:0]      app_rx_data             ,
input  wire                [15:0]     app_rx_data_length      ,
input                                 read_finish             ,
input                                 write_finish            ,

output     				[1:0]      Sdram_index,            //读写SDRAM的索引       
output   				[1:0]      read_ch,                //读端口选择信号
output   				[1:0]      write_ch,               //写端口选择信号
output     				[31:0]     sd_card_bmp_read_addr  //SD卡的读地址
);

reg                 [15:0]         cnt                         ;
wire                [31:0]         data_out                    ;
reg                 [63:0]         data_out_a                  ;
reg                 [63:0]         data_out_b                  ;

reg 							   read_finish_sync1; 
reg 							   read_finish_sync2;
reg 							   write_finish_sync1;
reg 							   write_finish_sync2;


// assign move_type = data_out[3:0];
// assign SDRAM_index = data_out[5:4];
// assign SD_card_index = data_out[15:6];
// assign sd_card_bmp_read_addr = (SD_card_index - 1)*1800 + 8484;         //这个地址是随便加的吧

// assign data_out = data_out_b[47:16];

//对write或者read_finish延时两个时钟
always @(posedge udp_rx_clk or negedge reset) begin
    if (!reset) begin
        read_finish_sync1 <= 1'b0;
        read_finish_sync2 <= 1'b0;
        write_finish_sync1 <= 1'b0;
        write_finish_sync2 <= 1'b0;
    end else begin
        read_finish_sync1 <= read_finish;
        write_finish_sync1 <= write_finish;
        read_finish_sync2 <= read_finish_sync1;
        write_finish_sync2 <= write_finish_sync1;
    end
end
	
always @(posedge udp_rx_clk or negedge reset)
begin
    if(!reset)  begin
    cnt   <=16'b0;
    end else if (app_rx_data_valid & cnt<(app_rx_data_length-1))begin
        cnt<=cnt+1;
    end else if (app_rx_data_valid & cnt==(app_rx_data_length-1))
        cnt<=16'b0;        
    else begin 
        cnt<=cnt;
    end
end

always @(posedge udp_rx_clk or negedge reset)
begin
    if(!reset)
      data_out_a<=64'b0;
    else if (app_rx_data_valid)
    case (cnt)
        0:data_out_a[63:56]<=app_rx_data;
        1:data_out_a[55:48]<=app_rx_data;
        2:data_out_a[47:40]<=app_rx_data;//这四个byte是有效数据
        3:data_out_a[39:32]<=app_rx_data;//
        4:data_out_a[31:24]<=app_rx_data;//
        5:data_out_a[23:16]<=app_rx_data;//
        6:data_out_a[15:8] <=app_rx_data;
        7:data_out_a[7:0]  <=app_rx_data;
    endcase                                      
    else begin
    data_out_a <=data_out_a;
    end
end

always@(posedge udp_rx_clk or negedge reset)
if(!reset)
    data_out_b <= 64'b0;
else if(cnt == (app_rx_data_length-1))begin
    if(read_finish_sync2==1||write_finish_sync2==1)begin
        data_out_b <= 64'b0;
    end else begin
        data_out_b <= data_out_a;
    end
end
   

decode u1_decode(
.clk                    (udp_rx_clk),                    //时钟
.rst_n                  (reset),                  //复位信号
.command_byte           (data_out_b[47:16]),           //命令数据

.Sdram_index            (SDRAM_index),            //读写SDRAM的索引       
.read_ch                (read_ch),                //读端口选择信号
.write_ch               (write_ch),               //写端口选择信号
.sd_card_bmp_read_addr  (sd_card_bmp_read_addr)   //SD卡的读地址
);


endmodule
