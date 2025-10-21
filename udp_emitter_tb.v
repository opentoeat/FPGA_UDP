`timescale 1ns/1ps
module tb_full_udp_temac;

// 1. 定义参数（对齐用户代码与文档）
// 器件与网络参数
parameter DEVICE             = "EG4X20BG256";       // 适配用户FPGA型号
parameter LOCAL_UDP_PORT_NUM = 16'd8080;            // 本地UDP端口（文档3.1节可配置参数）
parameter LOCAL_IP_ADDRESS   = 32'hC0A8F001;        // 本地IP：192.168.240.1（文档图5-2）
parameter LOCAL_MAC_ADDRESS  = 48'h001122334455;    // 本地MAC（文档3.1节）
parameter DST_UDP_PORT_NUM   = 16'd8080;            // 目标UDP端口
parameter DST_IP_ADDRESS     = 32'hC0A8F002;        // 目标IP：192.168.240.2（文档图5-2）
// 时钟参数（文档3.1节+用户代码）
parameter VIDEO_CLK_PERIOD  = 40;  // 视频时钟25MHz（1/25e6=40ns）
parameter GTX_CLK_PERIOD    = 8;   // TEMAC GTX时钟125MHz（文档3.1节TEMAC时钟）
parameter KEY1_PERIOD       = 1000;// 按键复位周期（模拟~key1低有效复位）
// 速率配置（文档5.3节多速率）
parameter TRI_speed         = 2'b10;// 1Gbps模式（00=10Mbps，01=100Mbps，10=1Gbps）

// 2. 声明信号（完全对齐用户代码连接）
// 全局时钟/复位
reg         video_clk;
reg         clk_125_out;    // 125MHz输入时钟（用户代码u5_temac_clk_gen的clk_125_in）
reg         clk_12_5_out;   // 12.5MHz（百兆）
reg         clk_1_25_out;   // 1.25MHz（十兆）
reg         rst_n;          // 低有效复位（用户代码）
reg         reset;          // 高有效复位（文档3.1节，协议栈/TEMAC用）
reg         key1;           // 按键复位（~key1作为u5的reset，低有效）
// 视频信号（模拟摄像头）
reg         de;
reg         hs;
reg         vs;
reg [15:0]  vout_data;      // 原始视频数据（RGB565）
// 视频延迟模块输出
wire        emitter_req;
wire        de_d;
wire [15:0] video_data_d;
// UDP emitter信号
wire [15:0] udp_data_length;
wire [7:0]  app_tx_data;
wire        app_tx_data_valid;
wire        app_tx_ack;
wire        udp_tx_ready;
wire        app_tx_data_request;
wire [3:0]  led;            // led[3] = udp_tx_ready，led[2:0]来自udp_emitter
// UDP协议栈信号（用户代码u3）
wire        app_rx_data_valid;
wire [7:0]  app_rx_data;
wire [15:0] app_rx_data_length;
wire [15:0] app_rx_port_num;
wire [15:0] input_local_udp_port_num;
wire        input_local_udp_port_num_valid;
wire [31:0] input_local_ip_address;
wire        input_local_ip_address_valid;
wire        ip_rx_error;
wire        arp_request_no_reply_error;
// UDP协议栈→TEMAC信号
wire [7:0]  temac_tx_data;
wire        temac_tx_valid;  // 低有效（文档3.1节）
wire        temac_tx_sof;    // 低有效（首字节）
wire        temac_tx_eof;    // 低有效（末字节）
wire        temac_tx_ready;  // 输入到协议栈，低有效（TEMAC就绪）
// TEMAC相关信号（用户代码u4）
wire        rx_clk_int;      // TEMAC接收时钟
wire        rx_clk_en_int;   // 接收时钟使能
wire [7:0]  rx_data;         // TEMAC接收数据
wire        rx_valid;        // 接收数据有效
wire        rx_correct_frame;// 接收正确帧
wire        rx_error_frame;  // 接收错误帧
wire        tx_clk_int;      // TEMAC发送时钟
wire        tx_clk_en_int;   // 发送时钟使能
wire [7:0]  tx_data;         // TEMAC发送数据
wire        tx_valid;        // 发送数据有效
wire        tx_rdy;          // TEMAC发送就绪（=temac_tx_ready）
wire        tx_stop;         // 发送停止（默认低）
wire        tx_collision;    // 发送冲突
wire        tx_retransmit;   // 重传
wire [7:0]  tx_ifg_val;      // 帧间间隙（文档3.1节，默认0x0C）
wire        pause_req;       // 流控请求（默认低）
wire [15:0] pause_val;       // 流控暂停值
wire [47:0] pause_source_addr;// 流控源MAC
wire [47:0] unicast_address; // 单播地址
wire [19:0] mac_cfg_vector;  // TEMAC配置向量（文档3.1节，默认0x00008）
// RGMII与PLL信号（用户代码rx_pll/u4）
reg        phy1_rgmii_rx_clk;    // PHY输入RGMII接收时钟
wire        phy1_rgmii_rx_clk_0;  // PLL输出0°时钟
wire        phy1_rgmii_rx_clk_90; // PLL输出90°时钟（u4的rgmii_rxc）
wire [3:0]  phy1_rgmii_tx_data;   // TEMAC输出RGMII发送数据
wire        phy1_rgmii_tx_ctl;    // RGMII发送控制
wire        phy1_rgmii_tx_clk;    // RGMII发送时钟
wire [3:0]  phy1_rgmii_rx_data;   // PHY输入RGMII接收数据
wire        phy1_rgmii_rx_ctl;    // RGMII接收控制
// UDP时钟生成模块输出（用户代码u5）
wire        udp_clk;         // UDP时钟（随TRI_speed切换）
// 收发FIFO信号（用户代码u6/u7）
wire        temac_rx_data;   // RX FIFO输出到协议栈的数据
wire        temac_rx_sof;    // RX FIFO输出首字节
wire        temac_rx_eof;    // RX FIFO输出末字节
wire        temac_rx_valid;  // RX FIFO输出数据有效（低有效）
wire        temac_rx_ready;  // 协议栈输出到RX FIFO的就绪（低有效）
wire        overflow_tx;     // TX FIFO溢出
wire        overflow_rx;     // RX FIFO溢出

// 3. 生成基础激励信号
// 3.1 时钟信号
initial begin
    video_clk = 1'b0;
    forever #(VIDEO_CLK_PERIOD/2) video_clk = ~video_clk;
end
initial begin
    clk_125_out = 1'b0;
    forever #(GTX_CLK_PERIOD/2) clk_125_out = ~clk_125_out;
end
initial begin
    clk_12_5_out = 1'b0;
    forever #(40) clk_12_5_out = ~clk_12_5_out; // 12.5MHz（80ns周期）
end
initial begin
    clk_1_25_out = 1'b0;
    forever #(400) clk_1_25_out = ~clk_1_25_out;// 1.25MHz（800ns周期）
end
initial begin
    phy1_rgmii_rx_clk = 1'b0;
    forever #(GTX_CLK_PERIOD/2) phy1_rgmii_rx_clk = ~phy1_rgmii_rx_clk; // RGMII时钟125MHz
end

// 3.2 复位信号（文档3.1节“复位高有效，≥1周期”）
initial begin
    rst_n = 1'b0;
    reset = 1'b1;
    key1 = 1'b0; // ~key1=1，u5复位
    #(GTX_CLK_PERIOD*20);  // 复位保持20个125MHz时钟（160ns）
    rst_n = 1'b1;
    reset = 1'b0;
    key1 = 1'b1; // ~key1=0，u5释放复位
end

// 3.3 视频信号（模拟1帧640x480 RGB565，触发emitter_req）
initial begin
    de = 1'b0;
    hs = 1'b0;
    vs = 1'b0;
    vout_data = 16'h0000;
    #(GTX_CLK_PERIOD*50);  // 复位后延迟
    
    forever begin
        // 场同步（vs低有效，触发emitter_req）
        vs = 1'b0;
        #(VIDEO_CLK_PERIOD*2);
        vs = 1'b1;
        #(VIDEO_CLK_PERIOD*10);
        
        // 模拟10行有效数据（简化验证）
        repeat(10) begin
            // 行同步（hs低有效）
            hs = 1'b0;
            #(VIDEO_CLK_PERIOD*2);
            hs = 1'b1;
            #(VIDEO_CLK_PERIOD*3);
            
            // 有效数据段（de高有效，20个像素）
            de = 1'b1;
            repeat(20) begin
                vout_data = vout_data + 16'h0001; // 递增数据，便于验证完整性
                #VIDEO_CLK_PERIOD;
            end
            de = 1'b0;
            #(VIDEO_CLK_PERIOD*5);
        end
        #(VIDEO_CLK_PERIOD*100); // 帧间间隔
    end
end

// 3.4 静态信号赋值（默认无效状态）
assign tx_stop = 1'b0;
assign tx_ifg_val = 8'h0C; // 帧间间隙12个周期（文档3.1节，1Gbps时96ns）
assign pause_req = 1'b0;
assign pause_val = 16'h0000;
assign pause_source_addr = LOCAL_MAC_ADDRESS;
assign unicast_address = LOCAL_MAC_ADDRESS;
assign mac_cfg_vector = 20'h00008; // TEMAC使能发送/接收（文档3.1节向量配置）
assign input_local_udp_port_num = LOCAL_UDP_PORT_NUM;
assign input_local_udp_port_num_valid = 1'b1;
assign input_local_ip_address = LOCAL_IP_ADDRESS;
assign input_local_ip_address_valid = 1'b1;

// 4. 例化用户代码中的所有模块（完全对齐用户连接）
// 4.1 视频延迟模块
video_udp_delay video_udp_delay(
    .video_clk(video_clk),
    .rst_n(rst_n),
    .de(de),
    .hs(hs),
    .vs(vs),
    .video_data(vout_data[15:0]),
    .emitter_req(emitter_req),
    .de_d(de_d),
    .video_data_d(video_data_d)
);

// 4.2 UDP发送模块
udp_emitter udp_emitter(
    .video_clk(video_clk),
    .udp_clk(udp_clk),
    .rst_n(rst_n),
    .video_de(de_d),
    .video_data(video_data_d),
    .emitter_req(emitter_req),
    .udp_length(2*1024 + 2), // 2050字节（用户配置）
    .udp_length_r(udp_data_length),
    .udp_tx_data(app_tx_data),
    .udp_tx_data_valid(app_tx_data_valid),
    .udp2_app_tx_ack(app_tx_ack),
    .udp2app_tx_ready(udp_tx_ready),
    .app_tx_request(app_tx_data_request),
    .led(led[2:0])
);
assign led[3] = udp_tx_ready; // 用户代码中的assign

// 4.3 UDP/IP协议栈模块
udp_ip_protocol_stack #(
    .DEVICE(DEVICE),
    .LOCAL_UDP_PORT_NUM(LOCAL_UDP_PORT_NUM),
    .LOCAL_IP_ADDRESS(LOCAL_IP_ADDRESS),
    .LOCAL_MAC_ADDRESS(LOCAL_MAC_ADDRESS)
) u3_udp_ip_protocol_stack(
    .udp_rx_clk(udp_clk),
    .udp_tx_clk(udp_clk),
    .reset(reset),
    .udp2app_tx_ready(udp_tx_ready),
    .udp2app_tx_ack(app_tx_ack),
    .app_tx_request(app_tx_data_request),
    .app_tx_data_valid(app_tx_data_valid),
    .app_tx_data(app_tx_data),
    .app_tx_data_length(udp_data_length),
    .app_tx_dst_port(DST_UDP_PORT_NUM),
    .ip_tx_dst_address(DST_IP_ADDRESS),
    .input_local_udp_port_num(input_local_udp_port_num),
    .input_local_udp_port_num_valid(input_local_udp_port_num_valid),
    .input_local_ip_address(input_local_ip_address),
    .input_local_ip_address_valid(input_local_ip_address_valid),
    .app_rx_data_valid(app_rx_data_valid),
    .app_rx_data(app_rx_data),
    .app_rx_data_length(app_rx_data_length),
    .app_rx_port_num(app_rx_port_num),
    .temac_rx_ready(temac_rx_ready),
    .temac_rx_valid(!temac_rx_valid), // 文档低有效，取反后输入
    .temac_rx_data(temac_rx_data),
    .temac_rx_sof(temac_rx_sof),
    .temac_rx_eof(temac_rx_eof),
    .temac_tx_ready(temac_tx_ready),
    .temac_tx_valid(temac_tx_valid),
    .temac_tx_data(temac_tx_data),
    .temac_tx_sof(temac_tx_sof),
    .temac_tx_eof(temac_tx_eof),
    .ip_rx_error(ip_rx_error),
    .arp_request_no_reply_error(arp_request_no_reply_error)
);

// 4.4 接收PLL模块（生成RGMII 90°时钟）
rx_pll u_rx_pll(
    .refclk(phy1_rgmii_rx_clk),
    .reset(1'b0),
    .clk0_out(phy1_rgmii_rx_clk_0),
    .clk1_out(phy1_rgmii_rx_clk_90)
);

// 4.5 TEMAC模块
temac_block#(
    .DEVICE(DEVICE)
) u4_trimac_block(
    .reset(reset),
    .gtx_clk(clk_125_out),
    .gtx_clk_90(clk_125_out), // 简化：125MHz 90°时钟（实际需PLL生成）
    .rx_clk(rx_clk_int),
    .rx_clk_en(rx_clk_en_int),
    .rx_data(rx_data),
    .rx_data_valid(rx_valid),
    .rx_correct_frame(rx_correct_frame),
    .rx_error_frame(rx_error_frame),
    .rx_status_vector(),
    .rx_status_vld(),
    .tx_clk(tx_clk_int),
    .tx_clk_en(tx_clk_en_int),
    .tx_data(tx_data),
    .tx_data_en(tx_valid),
    .tx_rdy(tx_rdy),
    .tx_stop(tx_stop),
    .tx_collision(tx_collision),
    .tx_retransmit(tx_retransmit),
    .tx_ifg_val(tx_ifg_val),
    .tx_status_vector(),
    .tx_status_vld(),
    .pause_req(pause_req),
    .pause_val(pause_val),
    .pause_source_addr(pause_source_addr),
    .unicast_address(unicast_address),
    .mac_cfg_vector(mac_cfg_vector),
    .rgmii_txd(phy1_rgmii_tx_data),
    .rgmii_tx_ctl(phy1_rgmii_tx_ctl),
    .rgmii_txc(phy1_rgmii_tx_clk),
    .rgmii_rxd(phy1_rgmii_rx_data),
    .rgmii_rx_ctl(phy1_rgmii_rx_ctl),
    .rgmii_rxc(phy1_rgmii_rx_clk_90),
    .inband_link_status(),
    .inband_clock_speed(),
    .inband_duplex_status()
);

// 4.6 UDP时钟生成模块
udp_clk_gen#(
    .DEVICE(DEVICE)
) u5_temac_clk_gen(
    .reset(~key1),
    .tri_speed(TRI_speed),
    .clk_125_in(clk_125_out),
    .clk_12_5_in(clk_12_5_out),
    .clk_1_25_in(clk_1_25_out),
    .udp_clk_out(udp_clk)
);

// 4.7 发送FIFO模块
tx_client_fifo #(
    .DEVICE(DEVICE)
) u6_tx_fifo(
    .rd_clk(tx_clk_int),
    .rd_sreset(reset),
    .rd_enable(tx_clk_en_int),
    .tx_data(tx_data),
    .tx_data_valid(tx_valid),
    .tx_ack(tx_rdy),
    .tx_collision(tx_collision),
    .tx_retransmit(tx_retransmit),
    .overflow(overflow_tx),
    .wr_clk(udp_clk),
    .wr_sreset(reset),
    .wr_data(temac_tx_data),
    .wr_sof_n(temac_tx_sof),
    .wr_eof_n(temac_tx_eof),
    .wr_src_rdy_n(temac_tx_valid), // 低有效，与temac_tx_valid一致
    .wr_dst_rdy_n(temac_tx_ready), // 低有效，TEMAC就绪
    .wr_fifo_status()
);

// 4.8 接收FIFO模块
rx_client_fifo#(
    .DEVICE(DEVICE)
) u7_rx_fifo(
    .wr_clk(rx_clk_int),
    .wr_enable(rx_clk_en_int),
    .wr_sreset(reset),
    .rx_data(rx_data),
    .rx_data_valid(rx_valid),
    .rx_good_frame(rx_correct_frame),
    .rx_bad_frame(rx_error_frame),
    .overflow(overflow_rx),
    .rd_clk(udp_clk),
    .rd_sreset(reset),
    .rd_data_out(temac_rx_data),
    .rd_sof_n(temac_rx_sof),
    .rd_eof_n(temac_rx_eof),
    .rd_src_rdy_n(temac_rx_valid), // 低有效，输出到协议栈
    .rd_dst_rdy_n(temac_rx_ready), // 低有效，协议栈就绪
    .rx_fifo_status()
);

// 5. 波形配置（重点观察文档要求的关键信号）
initial begin
    $dumpfile("tb_full_udp_temac.vcd");
    $dumpvars(0, tb_full_udp_temac);
    
    // 运行仿真（足够观察1帧传输+帧间隔）
    #(100000000); // 1ms，覆盖多周期验证
    $finish;
end

endmodule