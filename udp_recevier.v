module udp_recevier(
input           udp_clk,              //以太网时钟信号125mhz
input           ext_mem_clk,          //SDRAM时钟信号125mhz
input           rst_n,                  //复位信号，非全局复位 
input   [15:0]  app_rx_data_length,     //UDP包长
input   [7:0]   app_rx_data,            //数据信号
input           app_rx_data_valid,      //数据有效信号

output          App_wr_en,              //SDRAM写使能
output  [20:0]  App_wr_addr,            //SDRAM写地址
output  [1:0]   App_wr_dm,              //SDRAM写掩码
output  [31:0]  App_wr_din              //SDRAM写数据输入信号
);

//对数据有效信号进行处理延时,产生FIFO写使能信号
wire            data_en;                    //异步FIFO的写使能
wire [31:0]     fifo_wr_data;               //异步FIFO的写数据
reg             app_rx_data_valid_d0;
reg             app_rx_data_valid_d1;
wire            fifo_wr_en;                 //FIFO写使能
reg  [2:0]      byte_cnt;

always@(posedge udp_clk or negedge rst_n)begin
    if(!rst_n)begin
        app_rx_data_valid_d0    <= 1'b0;
        app_rx_data_valid_d1    <= 1'b0;
    end else begin
        app_rx_data_valid_d0    <= app_rx_data_valid;
        app_rx_data_valid_d1    <= app_rx_data_valid_d0;
    end
end

assign data_en = app_rx_data_valid_d1 & app_rx_data_valid;       //把前两个byte的数据排除

//数据拼接
always@(posedge udp_clk or negedge rst_n)begin
    if(~rst_n)begin
        pixel_data <= 16'd0;
    end else if(data_en)begin
        pixel_data <= {pixel_data[7:0],app_rx_data};
    end else begin
        pixel_data <= pixel_data;
    end
end
// reg [2:0] byte_cnt;
always@(posedge udp_clk or negedge rst_n)begin
    if(~rst_n)begin
        byte_cnt    <= 3'd0;
    end else if(fifo_wr_en) begin
        if(byte_cnt == 3'd1)begin
            byte_cnt <= 3'd0;
        end else begin
            byte_cnt <= byte_cnt + 3'd1;
        end
    end else begin
        byte_cnt <= 3'd0;
    end
end

reg [2:0] byte_cnt_d0;      //延时一个时钟周期

always@(posedge udp_clk or negedge rst_n)begin
    if(!rst_n)begin
        byte_cnt_d0 <= 3'd0;
    end else begin
        byte_cnt_d0 <= byte_cnt;
    end
end

// wire fifo_wr_en;    //FIFO写使能

assign fifo_wr_data = {16'd0,pixel_data};
assign fifo_wr_en = (byte_cnt_d0 == 3'd1);

receiver_buf receiver_buf
	(
	.clkr                      	(ext_mem_clk             ),          // Read side clock
	.clkw                      	(udp_clk                 ),          // Write side clock
	.rst                       	(acler                   ),          // Asynchronous clear
	.we                      	(fifo_wr_en              ),          // Write Request
	.re                      	(        		         ),          // Read Request
	.di                       	(fifo_wr_data             ),          // Input Data
	.empty_flag                 (                        ),          // Read side Empty flag
	.full_flag                  (                        ),          // Write side Full flag
	.wrusedw                	(              	  		 ),          // Read Used Words
	.rdusedw                	(rdusedw                 ),          // Write Used Words
	.dout                       (fifo_rd_data            )
);

//接下来从UDP向SDRAM中写数据需要画一个状态机
parameter IDLE = 3'd0;
parameter CHECK_FIFO = 3'd1;
parameter BURST_WRITE = 3'd2;
parameter BURST_END = 3'd3;
parameter WRITE_END = 3'd4;
parameter BURST_SIZE = 12'd512;

//三段式状态机
reg [2:0] state;
reg [2:0] next_state;

always@(posedge ext_mem_clk or negedge rst_n)begin
    if(!rst_n)begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

always@(*)begin
    case(state)
    IDLE:begin
        next_state <= CHECK_FIFO;
    end
    CHECK_FIFO:begin
        if(rdusedw >= BURST_SIZE)begin
            next_state <= BURST_WRITE;
        end else begin
            next_state <= CHECK_FIFO;
        end
    end
    BURST_WRITE:begin
        if(burst_cnt == BURST_SIZE - 1)begin
            next_state <= BURST_END;
        end else begin
            next_state <= BURST_WRITE;
        end
    end
    BURST_END:begin
        if(data_cnt == FRAME_SIZE - 1)begin
            next_state <= WRITE_END;
        end else begin
            next_state <= CHECK_FIFO;
        end
    end
    WRITE_END:begin
        next_state <= IDLE;
    end
    endcase
end
// output          App_wr_en,              //SDRAM写使能
// output  [20:0]  App_wr_addr,            //SDRAM写地址
// output  [1:0]   App_wr_dm,              //SDRAM写掩码
// output  [31:0]  App_wr_din              //SDRAM写数据输入信号
reg app_wr_en_r;            //SDRAM写使能
reg [20:0] app_wr_addr_r    //地址

assign      App_wr_dm = 2'd0;
reg [31:0]  app_wr_din_r;        //写数据寄存器
reg [20:0]  data_cnt;            //写数据计数器
reg [11:0]  burst_cnt;           //写 突发计数器
reg         fifo_rd_en_r;        //FIFO的读使能
wire        fifo_rd_en;          //
wire[31:0]  fifo_rd_data;        //读数据


assign fifo_rd_en = fifo_rd_en_r;

always@(posedge ext_mem_clk or rst_n)begin
    if(!rst_n)begin
        app_wr_en_r <= 1'b0;
        app_wr_addr_r <= 21'd0;
        data_cnt <= 21'd0;
        burst_cnt <= 12'd0;
        app_wr_din_r <= 32'd0;
        fifo_rd_en_r <= 1'b0;
    end else begin
        case(state)
        IDLE:begin
            app_wr_en_r <= 1'b0;
            app_wr_addr_r <= 21'd0;
            data_cnt <= 21'd0;
            burst_cnt <= 12'd0;
            app_wr_din_r <= 32'd0;
            fifo_rd_en_r <= 1'b0;
        end
        CHECK_FIFO:begin
            if(rdusedw >= BURST_SIZE)begin
                fifo_rd_en_r <= 1'b1
            end else begin
                fifo_rd_en_r <= 1'b0;
            end
        end
        BURST_WRITE:begin
            if(burst_cnt == BURST_SIZE)begin
                burst_cnt <= 1'b0;
                app_wr_en_r <= 1'b0;                //写到突发长度之后将写使能拉低
            end else begin
                burst_cnt <= burst_cnt + 1'd1;
                data_cnt <= data_cnt + 1'd1;
                app_wr_en_r <= 1'b1;
                app_wr_addr_r <= app_wr_addr_r + 21'd1;
            end
        end
        BURST_END:begin
            if(data_cnt == FRAME_SIZE)begin
                app_wr_addr_r <= 21'd0;
                data_cnt <= 21'd0;
                fifo_rd_en_r <= 1'b0;
            end else begin
                app_wr_addr_r <= app_wr_addr_r;
                data_cnt <= data_cnt;
            end
        end
        WRITE_END:begin
        end
        endcase
    end
end

assign App_wr_addr = app_wr_addr_r;
assign App_wr_din = fifo_rd_data;
assign App_wr_dm = 2'd0;
assign App_wr_en = app_wr_en_r;

endmodule 
