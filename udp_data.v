module udp_data(
 input                          app_rx_data_valid       ,
 input                 [7:0]    app_rx_data             ,
 input  wire           [15:0]   app_rx_data_length      ,
 input                          udp_rx_clk              ,
 input  wire                    reset                   ,

 output                [31:0]   data_out 
 );

reg                [15:0]     cnt                         ;
reg                [63:0]     data_out_a                  ;

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
    else
    data_out_a <=data_out_a;
end

assign  data_out = data_out_a[47:16];

endmodule

