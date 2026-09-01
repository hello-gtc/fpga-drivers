/*******************************************************************************
  ██████╗ ████████╗ ██████╗     ██████╗ ███████╗███████╗██╗ ██████╗ ███╗   ██╗
 ██╔════╝ ╚══██╔══╝██╔════╝     ██╔══██╗██╔════╝██╔════╝██║██╔════╝ ████╗  ██║
 ██║  ███╗   ██║   ██║          ██║  ██║█████╗  ███████╗██║██║  ███╗██╔██╗ ██║
 ██║   ██║   ██║   ██║          ██║  ██║██╔══╝  ╚════██║██║██║   ██║██║╚██╗██║
 ╚██████╔╝   ██║   ╚██████╔╝    ██████╔╝███████╗███████║██║╚██████╔╝██║ ╚████║
  ╚═════╝    ╚═╝    ╚═════╝     ╚═════╝ ╚══════╝╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝
 *******************************************************************************/
/*  brief:  实现 clk 生成iic 的状态机控制
    time:   2026-07-26
*/ 

module iic_gen_clk #(
        parameter CLK_FREQ      = 26'd50_000_000,       // 模块输入的时钟频率
        parameter IIC_FREQ      = 18'd250_000           // iic_scl 的频率
)(
        // 系统输入
        input   wire            clk,            // 系统时钟       
        input   wire            rst_n,          // 系统复位
        // 上层输入 读写控制
        input   wire            scl_ctrl,       // scl 时钟开关（高电平有效）
        // 输出给上层 两个时钟信号   
        output  reg             iic_opera_clk,  // iic 驱动操作时钟
        output  reg             scl             // iic scl 线
);

//---------------------------------------------------------------------------- 获取scl时钟 和 sda 操作时钟（四倍频率关系）
        // iic_opera_clk 直接一直产生
        localparam      SCL_CNT_MAX             = CLK_FREQ / IIC_FREQ;  // scl计数器 最大值
        localparam      OPERA_CLK_CNT_MAX       = SCL_CNT_MAX >> 2;     // opera_clk 计数最大值（频率4倍）
        reg[5:0]        opera_clk_cnt;

        always @(posedge clk, negedge rst_n) begin      // 只opera_clk_cnt计数 时序逻辑
                if(!rst_n) begin
                        opera_clk_cnt <= 6'b0;
                end
                else begin
                        if(opera_clk_cnt < OPERA_CLK_CNT_MAX-1) opera_clk_cnt <= opera_clk_cnt+1;
                        else                                    opera_clk_cnt <= 6'b0;
                end
        end
        always @(posedge clk, negedge rst_n) begin      // iic_opera_clk 时序逻辑
                if(!rst_n) begin
                        iic_opera_clk <= 1'b0;
                end
                else begin
                        if(opera_clk_cnt == OPERA_CLK_CNT_MAX/2-1)      iic_opera_clk <= ~iic_opera_clk;
                        else if(opera_clk_cnt == OPERA_CLK_CNT_MAX-1)   iic_opera_clk <= ~iic_opera_clk;
                        else                                            iic_opera_clk <= iic_opera_clk;
                end
        end

        // scl 时钟信号产生
        reg[1:0]        scl_cnt;        // scl 时钟计数器
        localparam      DIVI_CNT = 4;   // 分频4倍
        always @(posedge iic_opera_clk, negedge rst_n) begin      // 只scl_cnt计数 时序逻辑
                if(!rst_n) begin
                        scl_cnt <= 2'b0;
                end
                else begin
                        if(scl_ctrl) begin      
                                if(scl_cnt != DIVI_CNT/2) begin
                                        scl_cnt <= scl_cnt + 1;
                                end
                                else    scl_cnt <= 2'b1;
                        end
                        else    scl_cnt <= 2'b0;
                end
        end
        always @(posedge iic_opera_clk, negedge rst_n) begin      // scl 时序逻辑
                if(!rst_n) begin
                        scl     <= 1'b1;
                end
                else begin
                        if(scl_ctrl) begin
                                if(scl_cnt == 2'd2)     scl <= ~scl;
                                else                    scl <= scl;
                        end 
                        else    scl <= 1'b1;
                end
        end
endmodule
