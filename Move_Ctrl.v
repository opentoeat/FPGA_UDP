module Move_Ctrl(
//复位信号
input           rst_n,
//时钟信号
input           ext_mem_clk,
input           sd_card_clk,
input           clk_50,
input           video_clk,
input 			cam_pclk,
//SDRAM信号
input           Sdr_init_done,      //初始化完成信号
input           Sdr_init_ref_vld,   //刷新有效信号
input           Sdr_busy,           //读写忙信号

output          App_rd_en,      //读使能
output  [20:0]  App_rd_addr,    //读地址
input           Sdr_rd_en,      //读数据有效信号
input   [31:0]  Sdr_rd_dout,    //读数据

output          App_wr_en,      //写使能信号
output  [20:0]  App_wr_addr,    //写地址信号
output  [31:0]  App_wr_din,     //写数据
output          App_wr_dm,      //写数据掩码，控制四个byte哪个有效的信号

//SD_card信号
//读SD卡信号
input           sd_card_write_req,
output          sd_card_write_req_ack,
input           sd_card_write_en,
input   [23:0]  sd_card_write_data,
//写SD卡信号
input           sd_card_read_req,
output          sd_card_read_req_ack,
input           sd_card_read_en,
output   [23:0] sd_card_read_data,

//camera信号
input           cam_write_req,
input           cam_write_req_ack,
input           cam_write_en,
input   [23:0]  cam_write_data,
//HDMI信号
input           video_read_req,
output          video_read_req_ack,
input           video_read_en,
output  [23:0]  video_read_data,

//读bmp图片使能信号
output          Out_sd_card_bmp_read,       //读一张bmp图片的使能
output  [31:0]  Out_sd_card_bmp_read_addr,  //读哪一张bmp图片


//Top_Ctrl信号
input 	[1:0]	Sdram_index,			//读写SDRAM的索引
input   [1:0]	read_ch,				//都端口选择信号
input   [1:0]	write_ch,				//写端口的选择信号
input   [31:0]	sd_card_bmp_read_addr,	//sd卡的读地址

//
output  		write_finish,
output 			read_finish				//读写完成信号
);

//需要包含什么信号
//写端口的选择信号
//写端口的index			
//都端口的选择信号
//读端口的index			//这两个应该一样
//sd卡的地址大小
//无了

//定义信号
//读信号组
reg             read_clk_r;
reg             read_req_r;
reg             read_req_ack_r;
reg    [1:0]    read_addr_index_r;
reg             read_en_r;
reg    [31:0]   read_data_r;

wire            read_clk;
wire            read_req;
wire            read_req_ack;
wire    [1:0]   read_addr_index;
wire            read_en;
wire    [31:0]  read_data;
//写信号
reg             write_clk_r;
reg             write_req_r;
reg             write_req_ack_r;
reg    [1:0]    write_addr_index_r;
reg             write_en_r;
reg    [31:0]   write_data_r;

wire            write_clk;
wire            write_req;
wire            write_req_ack;
wire    [1:0]   write_addr_index;
wire            write_en;
wire    [31:0]  write_data;

always@(*)begin
	case (write_ch)
		2'd0:begin		//摄像头写
			write_clk_r = cam_pclk;
			write_req_r = cam_write_req;
//			write_req_ack_r = 
			write_addr_index_r = Sdram_index;
			write_en_r = cam_write_en;
			write_data_r = {8'd0,cam_write_data};
		end
		2'd1:begin
			write_clk_r = sd_card_clk;
			write_req_r = sd_card_write_req;
//			write_req_ack_r = 
			write_addr_index_r = Sdram_index;
			write_en_r = sd_card_read_en;
			write_data_r = {8'd0,sd_card_write_data};
		end
		2'd2:begin
		end
		2'd3:begin
		end 
		default:begin
		end
	endcase
end

always@(*)begin
	case(read_ch)
	2'd0:begin
		read_clk = sd_card_clk;
		read_req_r = sd_card_read_req;
		read_addr_index = Sdram_index;
		read_en_r = sd_card_read_en;
		sd_card_read_data = read_data;
	end
	2'd1:begin
		read_clk = video_clk;
		read_req_r = video_read_req;
		read_addr_index = Sdram_index;
		read_en_r = video_read_en;
		sd_card_read_data = video_read_data;
	end
	2'd2:begin
	end
	2'd3:begin
	end
	default:begin
	end
	endcase
end



//例化帧读写模块
frame_read_write frame_read_write_m0(
    .mem_clk					(ext_mem_clk),
    .rst						(~rst_n),
    .Sdr_init_done				(Sdr_init_done),
    .Sdr_init_ref_vld			(Sdr_init_ref_vld),
    .Sdr_busy					(Sdr_busy),
    
    .App_rd_en					(App_rd_en),
    .App_rd_addr				(App_rd_addr),
    .Sdr_rd_en					(Sdr_rd_en),
    .Sdr_rd_dout				(Sdr_rd_dout),
    
    .read_clk                   (read_clk),//(video_clk           ),
	.read_req                   (read_req),//(video_read_req           ),
	.read_req_ack               (read_req_ack),//(video_read_req_ack       ),
	.read_finish                (                   ),
	.read_addr_0                (24'd0              ), //第一张照片//first frame base address is 0
	.read_addr_1                (24'd307204         ), //第二张图片
	.read_addr_2                (24'd0              ), //
	.read_addr_3                (24'd0              ),
	.read_addr_index            (2'd0               ), //use only read_addr_0
	.read_len                   (24'd307200         ), //frame size//24'd786432
	.read_en                    (read_en),//(video_read_en            ),
	.read_data                  (read_data),//(video_read_data          ),
    
    .App_wr_en					(App_wr_en),
    .App_wr_addr				(App_wr_addr),
    .App_wr_din					(App_wr_din),
    .App_wr_dm					(App_wr_dm),
    
    .write_clk                  (write_clk),//sd_card_clk        ),
	.write_req                  (write_req),//sd_card_write_req        ),
	.write_req_ack              (write_req_ack),//sd_card_write_req_ack    ),
	.write_finish               (),                         //SDRAM时钟控制
	.write_addr_0               (24'd0            ),
	.write_addr_1               (24'd307204       ),
	.write_addr_2               (24'd0            ),
	.write_addr_3               (24'd0            ),
	.write_addr_index           (2'd0             ), //use only write_addr_0
	.write_len                  (24'd307200       ), //frame size
	.write_en                   (write_en),//sd_card_write_en         ),
	.write_data                 (write_data),//,sd_card_write_data       ),
    
    .state                      ()
);



endmodule
