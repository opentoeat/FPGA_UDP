module frame_ctrl(
    input       video_clk   ,           //视频时钟
    input       mem_clk     ,           //sdram时钟
    input       rst_n       ,           //复位信号
    input       read_finish ,          //读完成信号，由sdram时钟驱动
    input       key_in      ,           //脉冲信号 ，时钟需要匹配

    output      enable                  //接下来模块的video_timing_data ，时钟与下面的video_timing_data一样              
);
wire read_finish_back;
reg read_finish_wide;       //展宽之后的信号
reg enable_r;
//将read_finish 信号展宽
always@(posedge mem_clk or negedge rst_n)begin
    if(!rst_n)begin
        read_finish_wide <= 1'b0;
    end else begin
        if(read_finish)begin
            read_finish_wide <= 1'b1;
        end else if(read_finish_back)begin
            read_finish_wide <= 1'b0;
        end
    end
end

//打两排
always@(posedge video_clk or negedge rst_n)begin
    if(!rst_n)begin
        sync_0 <= 1'b0;
        sync_1 <= 1'b0;
    end else begin
        sync_0 <= read_finish_wide;
        sync_1 <= sync_0;
    end
end

//enable 
always @(posedge video_clk or negedge rst_n) begin
    if(!rst_n)begin
        enable_r <= 1'b0; 
    end else if (sync_1)begin
        enable_r <= 1'b0;
    end else if (key_in)begin
        enable_r <= 1'b1;
    end else begin
        enable_r <= 1'b0;
    end
end

//assign 赋值
assign enable = enable_r;
assign read_finish_back = sync_1;

endmodule