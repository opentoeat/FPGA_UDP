module udp_emitter(
input       video_clk,            //video_clk
input       udp_clk,                //以太网时钟
input       rst_n,                  //复位信号

input           video_de                ,//视频有效信号
input [15:0]    video_data              ,


input       [15:0]   udp_length              ,//udp包的数据长度
output  reg [15:0]   udp_length_r            ,
output  reg [7:0]    udp_tx_data             ,//udp数据
output  reg          udp_tx_data_valid       ,//udp数据有效信号
input                udp2_app_tx_ack         ,
input                udp2app_tx_ready        ,
output  reg          app_tx_request             //发送请求信号
);

wire [7:0] fifo_rd_data;
reg        fifo_rd_en;          //FIFO的读使能

//加一个异步FIFO,通过判断读余量的剩余往上发数据
udp_buf emitter_buf
	(
	.clkr                      	(udp_clk                  ),          // Read side clock
	.clkw                      	(video_clk                ),          // Write side clock
	.rst                       	(rst_n                    ),          // Asynchronous clear
	.we                      	(video_de                 ),          // Write Request
	.re                      	(fifo_rd_en        		  ),          // Read Request
	.di                       	(video_data               ),          // Input Data
	.empty_flag                 (                         ),          // Read side Empty flag
	.full_flag                  (                         ),          // Write side Full flag
	.wrusedw                	(              	  		  ),          // Read Used Words
	.rdusedw                	(rdusedw                  ),          // Write Used Words
	.dout                       (fifo_rd_data		          )
);

/*
状态机
IDLE
CHECK_FIFO
SEND_REQ
SEND_DATA
SEND_END
不要req了，直接对读出的数据进行计数应该就可以了
*/
parameter IDLE = 3'd0;
parameter CHECK_FIFO = 3'd1;
parameter SEND_REQ = 3'd2;
parameter SEND_DATA = 3'd3;
parameter SEND_END = 3'd4;

reg [2:0] state;
reg [2:0] next_state;


always@(posedge udp_clk or negedge rst_n)begin
    if(!rst_n)begin
        state <= IDLE;
    end else begin
        stata <= next_state;
    end
end

always@(*)begin
    case (stata)
        IDLE:begin
            if(emitter_req)begin
                next_state <= CHECK_FIFO;
            end else begin
                next_state <= IDLE;
            end
        end
        CHECK_FIFO: begin
            if(rdusedw > udp_length)begin
                next_state <= SEND_REQ;
            end else begin
                next_state <= CHECK_FIFO;
            end
        end
        SEND_REQ:begin
            if(~udp2app_tx_ready & udp2_app_tx_ack)begin
                next_state <= SEND_DATA;
            end else begin
                next_state <= SEND_REQ;
            end
        end
        SEND_DATA:begin
            if((data_cnt == udp_length)&(v_cnt == V_DISP - 1))begin
                next_state <= SEND_END;
            end else if(data_cnt == udp_length)begin
                next_state <= CHECK_FIFO;
            end else begin
                next_state <= SEND_DATA;
            end
        end
        SEND_END:begin//清空一下FIFO等待下一张图片的写入，应该两张发一张的
            next_state <= IDLE;
        end
        default:next_state <= IDLE;
    endcase
end

//列举一下需要使用的变量
//1.包长的寄存器
//2.udp数据有效信号
//3.udp数据信号
reg [10:0]      data_cnt;       //数据计数器
reg [15:0]      v_cnt;          //列计数器

always@(posedge udp_clk or negedge rst_n)begin
    if(!rst_n)begin
        udp_length_r        <=  16'd0;
        udp_tx_data_valid   <=  1'b0;
        udp_tx_data         <=  8'd0;
        data_cnt            <=  11'd0;
        fifo_rd_en          <=  1'b0;
        app_tx_request      <=  1'b0;
    end else begin
        case (state)
            IDLE:begin
                acler <= 1'b0;
                if(emitter_req)begin
                    udp_length_r        <= udp_length;
                    udp_tx_data_valid   <= 1'b0;
                    udp_tx_data         <= 8'd0;
                    data_cnt            <= 11'd0;
                end else begin
                    udp_length_r        <= 16'd0;
                    udp_tx_data_valid   <= 1'b0;
                    udp_tx_data         <= 8'd0;
                    data_cnt            <= 11'd0;
                end
            end
            CHECK_FIFO:begin
                data_cnt <= 16'd0;
                if(rdusedw > udp_length)begin
                    app_tx_request <= 1'b1;
                    v_cnt <= v_cnt + 16'd1;        
                end else begin
                    v_cnt <= v_cnt;
                end
            end
            SEND_REQ:begin
                if(udp2_app_tx_ack&~udp2app_tx_ready)begin
                    app_tx_request <= 1'b0;
                end else begin
                    app_tx_request <= app_tx_request;
                end
            end
            SEND_DATA:begin
                case (data_cnt)
                    16'd0:begin
                        udp_tx_data_valid   <= 1'b1;
                        udp_tx_data         <= v_cnt[15:8];
                        data_cnt            <= data_cnt + 16'd1;
                        fifo_rd_en          <= 1'b1;                //第一个时钟拉高
                    end
                    16'd1:begin
                        udp_tx_data_valid   <= 1'b1;
                        udp_tx_data         <= v_cnt[7:0];
                        data_cnt            <= data_cnt + 16'd1;
                        fifo_rd_en          <= 1'b1;
                    end
                    udp_length_r-2:begin
                        udp_tx_data_valid   <= 1'b1;
                        udp_tx_data         <= fifo_rd_data;
                        data_cnt            <= data_cnt + 16'd1;
                        fifo_rd_en          <= 1'b0;                //FIFO读使能拉低，之后就不读数据了
                    end
                    udp_length_r-1:begin
                        udp_tx_data_valid   <= 1'b1;
                        udp_tx_data         <= fifo_rd_data;
                        data_cnt            <= data_cnt + 16'd1;
                        fifo_rd_en          <= 1'b0;
                    end
                    udp_length_r:begin
                        udp_tx_data_valid   <= 1'b0;
                        udp_tx_data         <= 8'd0;
                    end
                    default:begin
                        udp_tx_data         <= fifo_rd_data;        //第三个时钟之后将fifo中的数据读出给udp_tx_data
                        udp_tx_data_valid   <= 1'b1;                //使能为1，代表这个数据有效
                    end
                endcase
            end
            SEND_END:begin
                v_cnt <= 16'd0;
                acler <= 1'b1;
            end 
            default: 
        endcase
    end   
end

endmodule 

