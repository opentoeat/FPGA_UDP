module frame_header_detect(
input           rst_n,                  //复位信号，非全局复位 
input   [15:0]  app_rx_data_length,     //UDP包长
input   [7:0]   app_rx_data,            //数据信号
input           app_rx_data_valid,      //数据有效信号
input           udp_clk,              //以太网时钟信号125mhz

output          jump
);
/*输出应该输出什么呢
这个模块就是检测帧头的，
当检测到帧头的时候，
*/
//先检测上升沿
reg app_rx_data_valid_d0;
reg app_rx_data_valid_d1;
assign pos_rx_vld = ~app_rx_data_valid_d0 & app_rx_data_valid;
//
//延迟两个时钟周期
always@(posedge udp_clk or negedge rst_n)begin
    if(~rst_n)begin
        app_rx_data_valid_d0 <= 1'b0;
        app_rx_data_valid_d1 <= 1'b0;
    end else begin
        app_rx_data_valid_d0 <= app_rx_data_valid;
        app_rx_data_valid_d1 <= app_rx_data_valid_d0;
    end
end

always@(posedge udp_clk or negedge rst_n)begin
    if(~rst_n)begin
        app_rx_data_d0 <= 1'b0;
        app_rx_data_d1 <= 1'b0;
    end else begin
        app_rx_data_d0 <= app_rx_data;
        app_rx_data_d1 <= app_rx_data_d0;
    end
end

assign frame_header = (app_rx_data == 8'd0) & (app_rx_data_d0 == 8'd0);

assign  jump = frame_header & pos_rx_vld;

endmodule 