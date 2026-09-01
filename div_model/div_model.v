/*******************************************************************************
  ██████╗ ████████╗ ██████╗     ██████╗ ███████╗███████╗██╗ ██████╗ ███╗   ██╗
 ██╔════╝ ╚══██╔══╝██╔════╝     ██╔══██╗██╔════╝██╔════╝██║██╔════╝ ████╗  ██║
 ██║  ███╗   ██║   ██║          ██║  ██║█████╗  ███████╗██║██║  ███╗██╔██╗ ██║
 ██║   ██║   ██║   ██║          ██║  ██║██╔══╝  ╚════██║██║██║   ██║██║╚██╗██║
 ╚██████╔╝   ██║   ╚██████╔╝    ██████╔╝███████╗███████║██║╚██████╔╝██║ ╚████║
  ╚═════╝    ╚═╝    ╚═════╝     ╚═════╝ ╚══════╝╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝
 *******************************************************************************/
/*  brief:  实现 div_model.v
    time:   2026-08-08
*/ 

module div_model #(
        parameter       DATA_WIDTH = 10'd8
)(
        input   wire                    sys_clk,        // 系统时钟
        input   wire                    sys_rst_n,      // 系统复位时钟
        input   wire                    en,             // 使能信号（高脉冲有效）
        input   wire[DATA_WIDTH/2-1:0]  dividend,       // 被除数
        input   wire[DATA_WIDTH/2-1:0]  divisor,        // 除数

        output  wire                    ready,          // 可以接收信号 标志
        output  wire[DATA_WIDTH-1:0]    quotient,       // 商
        output  wire[DATA_WIDTH-1:0]    remainder,      // 余数
        output  wire                    vld_out         // 输出有效标志（高电平）
);
//---------------------------------------------------------------------- 使能信号上升沿捕捉
        wire    pos_en;
        reg     en_delay0;
        reg     en_delay1;

        always @(posedge sys_clk, negedge sys_rst_n) begin
                if(!sys_rst_n) begin
                        en_delay0       <= 1'b0;
                        en_delay1       <= 1'b0;
                end
                else begin
                        en_delay0       <= en;
                        en_delay1       <= en_delay1;
                end
        end
        assign  pos_en  = en_delay0 &(~en_delay1);

//---------------------------------------------------------------------- 信号寄存信号
        reg[DATA_WIDTH-1:0]     reg_dividend;           // 被除数 寄存
        reg[DATA_WIDTH-1:0]     reg_divisor;            // 除数   寄存      
        reg[DATA_WIDTH-1:0]     dividend_delay0;        // 被除数 打一拍
        reg[DATA_WIDTH-1:0]     divisor_delay0;         // 除数   打一拍

        always @(posedge sys_clk, negedge sys_rst_n) begin
                if(!sys_rst_n) begin
                        reg_dividend    <= {DATA_WIDTH{1'b0}};
                        reg_divisor     <= {DATA_WIDTH{1'b0}};
                        dividend_delay0 <= {DATA_WIDTH{1'b0}};
                        divisor_delay0  <= {DATA_WIDTH{1'b0}};
                end
                else begin
                        dividend_delay0 <= dividend;
                        divisor_delay0  <= divisor;
                        if(pos_en) begin
                                reg_dividend                            <= dividend_delay0;
                                reg_divisor[DATA_WIDTH/2-1:0]           <= divisor_delay0[DATA_WIDTH-1:DATA_WIDTH/2];
                                reg_divisor[DATA_WIDTH-1:DATA_WIDTH/2]  <= divisor_delay0[DATA_WIDTH/2-1:0];
                        end
                end
        end

//---------------------------------------------------------------------- 状态机 定义
        localparam      st_idle         = 3'b001;       // 空闲状态
        localparam      st_opera        = 3'b010;       // 操作状态
        localparam      st_end          = 3'b100;       // 结束状态

        reg[2:0]        curr_state;
        reg[2:0]        next_state;
        wire            st_done;
        reg             st_flag;
        reg             st_flag_delay0;
        always @(posedge sys_clk, negedge sys_rst_n) begin
                if(!sys_rst_n)  st_flag_delay0 <= 1'b0;
                else            st_flag_delay0 <= st_flag;
        end
        assign          st_done = st_flag & (~st_flag_delay0);

//---------------------------------------------------------------------- 状态机 时序转移
        always @(posedge sys_clk, negedge sys_rst_n) begin
                if(!sys_rst_n) begin
                        curr_state      <= st_idle;
                        next_state      <= st_idle;
                end
                else    curr_state      <= next_state;
        end

//---------------------------------------------------------------------- 状态机 组合逻辑
        always @(*) begin
                case(curr_state)
                        st_idle:        begin
                                if(pos_en)      next_state = st_opera;
                                else            next_state = st_idle;
                        end
                        st_opera:       begin
                                if(st_done)     next_state = st_end;
                                else            next_state = st_opera;
                        end
                        st_end:         begin
                                if(st_done)     next_state = st_idle;
                                else            next_state = st_end;
                        end
                endcase
        end

//---------------------------------------------------------------------- 中间信号定义
        reg                     reg_ready;      // ready signal
        reg[DATA_WIDTH-1:0]     reg_quotient;   // 商    signal
        reg[DATA_WIDTH-1:0]     reg_remainder;  // 余数  signal
        reg                     reg_vld_out;    // 输出数据有效 flag

        assign  ready           = reg_ready;
        assign  quotient        = reg_quotient;
        assign  remainder       = reg_remainder;
        assign  vld_out         = reg_vld_out;

//---------------------------------------------------------------------- 状态机 时序输出
        reg[9:0]                opera_cnt;
        reg                     vld_out_li;
        wire[DATA_WIDTH-1:0]    result_temp;
        assign                  result_temp = reg_dividend-reg_divisor+1;
        



        always @(posedge sys_clk, negedge sys_rst_n) begin
                if(!sys_rst_n) begin
                        reg_ready               <= 1'b0;
                        reg_quotient            <= {DATA_WIDTH {1'b0}};
                        reg_remainder           <= {DATA_WIDTH {1'b0}};
                        reg_vld_out             <= 1'b0;

                        opera_cnt               <= 10'b0;
                        vld_out_li              <= 1'b0;
                end
                else begin
                        case(curr_state)
                                st_idle:        begin
                                        opera_cnt               <= 10'b0;
                                        reg_ready               <= 1'b1;
                                        reg_quotient            <= {DATA_WIDTH {1'b0}};
                                        reg_remainder           <= {DATA_WIDTH {1'b0}};
                                        reg_vld_out             <= 1'b0;
                                        vld_out_li              <= 1'b0;
                                        st_flag                 <= 1'b0;
                                end
                                st_opera:       begin
                                        reg_ready               <= 1'b0;
                                        if(opera_cnt <= (DATA_WIDTH/2-1) && (st_done!= 1)) begin
                                                if(reg_dividend < reg_divisor) begin
                                                        if(opera_cnt == DATA_WIDTH/2) begin
                                                                reg_dividend    <= reg_dividend;
                                                        end
                                                        else begin
                                                                reg_dividend    <= {reg_dividend[DATA_WIDTH-2:0], 1'b0};
                                                                opera_cnt       <= opera_cnt+1;
                                                                st_flag         <= 1'b0;
                                                        end
                                                end
                                                else if(reg_dividend > reg_divisor) begin
                                                        if(opera_cnt == DATA_WIDTH/2) begin
                                                                reg_dividend[DATA_WIDTH-1:0]    <= reg_dividend-reg_divisor+1;
                                                        end
                                                        else    reg_dividend[DATA_WIDTH-1:0]    <= {result_temp[DATA_WIDTH-2:0], 1'b0};
                                                        
                                                        opera_cnt               <= opera_cnt+1;
                                                        st_flag                 <= 1'b0;
                                                end
                                        end
                                        else begin    
                                                st_flag         <= 1'b1;
                                                opera_cnt       <= 10'b0;
                                        end
                                end
                                st_end:         begin
                                        st_flag                 <= 1'b0;
                                        opera_cnt <= opera_cnt + 1;
                                        if(!vld_out_li && opera_cnt <= 1) begin
                                                reg_quotient    <= reg_dividend[DATA_WIDTH/2-1:0];
                                                reg_remainder   <= reg_dividend[DATA_WIDTH-1:DATA_WIDTH/2];
                                                reg_vld_out     <= 1'b1;
                                                vld_out_li      <= vld_out_li + 1'b1;
                                        end
                                        else begin
                                                st_flag         <= 1'b1;
                                                reg_ready       <= 1'b1;
                                                reg_vld_out     <= 1'b0;
                                                opera_cnt       <= 10'b0;
                                        end
                                end     
                        endcase
                end
        end
endmodule
