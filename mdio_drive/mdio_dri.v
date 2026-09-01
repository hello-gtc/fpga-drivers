/*******************************************************************************
  ██████╗ ████████╗ ██████╗     ██████╗ ███████╗███████╗██╗ ██████╗ ███╗   ██╗
 ██╔════╝ ╚══██╔══╝██╔════╝     ██╔══██╗██╔════╝██╔════╝██║██╔════╝ ████╗  ██║
 ██║  ███╗   ██║   ██║          ██║  ██║█████╗  ███████╗██║██║  ███╗██╔██╗ ██║
 ██║   ██║   ██║   ██║          ██║  ██║██╔══╝  ╚════██║██║██║   ██║██║╚██╗██║
 ╚██████╔╝   ██║   ╚██████╔╝    ██████╔╝███████╗███████║██║╚██████╔╝██║ ╚████║
  ╚═════╝    ╚═╝    ╚═════╝     ╚═════╝ ╚══════╝╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝
 *******************************************************************************/
/*      brief:  mdio_drive.v
        time:   2026-08-11
*/

module mdio_dri #(
        parameter       PHY_ADDR        = 5'b00100,
        parameter       CLK_DIV         = 6'd48
)(
        input   wire            sys_clk,        // system clk 50Mhz
        input   wire            sys_rst_n,      // system to reset

        input   wire            op_exec,        // signal to start (high pulse)
        input   wire            op_rh_wl,       // signal to choose the kind of operation (1:read,0:write) 
        input   wire[4:0]       op_addr,        // the register's address
        input   wire[15:0]      op_wr_data,     // the data to write in 
        
        output  wire            op_done,        // signal to show operation have done
        output  wire[15:0]      op_rd_data,     // the data that are read out from PHY register
        output  wire            op_rd_ack,      // signal to show the data is ready to get by user
        output  wire            dri_clk,        // the clk to drive the operation 

        output  wire            eth_mdc,        // the wire mdc
        inout   wire            eth_mdio        // the wire mdio
);
//-------------------------------------------------------------------------------- the start signal is two taps
        reg             op_exec_delay0;
        reg             op_exec_tap;                            // benchmark signal
        always @(posedge dri_clk, negedge sys_rst_n) begin
                if(!sys_rst_n) begin
                        op_exec_tap     <= 1'b0;
                        op_exec_delay0  <= 1'b0;
                end
                else begin
                        op_exec_delay0  <= op_exec;
                        op_exec_tap     <= op_exec_delay0;
                end
        end

//-------------------------------------------------------------------------------- signal storage
        // reg define
        reg[15:0]       reg_wr_data;            // the data(16-bit) to write in  
        reg             reg_rh_wl;              // high to read and low to write 
        reg[4:0]        reg_op_addr;            // the address of register to operate

        reg[1:0]        op_code;                // 10:read  01:write
        // storage logic
        always @(posedge sys_clk, negedge sys_rst_n) begin
                if(!sys_rst_n) begin
                        reg_wr_data     <= 16'b0;
                        reg_rh_wl       <= 1'b0;
                        reg_op_addr    <= 5'b0;
                end
                else begin
                        if(op_exec_tap) begin           // store
                                reg_wr_data     <= op_wr_data;
                                reg_op_addr     <= op_addr;
                                reg_rh_wl       <= op_rh_wl;
                                op_code         <= op_rh_wl ? 2'b10 : 2'b01; 
                        end
                        else if(op_done) begin          // clear
                                reg_wr_data     <= 16'b0;
                                reg_rh_wl       <= 1'b0;
                        end
                        else begin                      // keep
                                reg_wr_data     <= reg_wr_data;
                                reg_rh_wl       <= reg_rh_wl;
                        end
                end
        end


//-------------------------------------------------------------------------------- generate the dri_clk
        gen_dri_clk #(
                .CLK_DIV        (CLK_DIV)
        )u_gen_dri_clk(
                .sys_clk        (sys_clk),
                .sys_rst_n      (sys_rst_n),
                .dri_clk        (dri_clk),
                .mdc_clk        (eth_mdc)
        );

//-------------------------------------------------------------------------------- define state machine
        localparam      st_idle         = 6'b000_001;   // state of idle 
        localparam      st_pre          = 6'b000_010;   // state of send pre 1*16
        localparam      st_start        = 6'b000_100;   // state of send start signal and operation code
        localparam      st_addr         = 6'b001_000;   // state of send PHY and register address
        localparam      st_wr_data      = 6'b010_000;   // state of send data 16 bits and back to idle
        localparam      st_rd_data      = 6'b100_000;   // state of read data 16 bits and back to idle

        reg[5:0]        curr_state;     // current state
        reg[5:0]        next_state;     // next    state

//-------------------------------------------------------------------------------- transfer state machine
        // reg define
        reg     st_done_flag;           // st_done_flag (catch the st_done_flag posedge to define a high level pulse)
        reg     st_done_flag_delay0;
        wire    st_done;                // a high level pulse

        // st_done_flag_delay0 
        always @(posedge dri_clk, negedge sys_rst_n) begin
                if(!sys_rst_n)  st_done_flag_delay0     <= 1'b0;
                else            st_done_flag_delay0     <= st_done_flag;
        end
        // assign st_done 
        assign  st_done = st_done_flag & (~st_done_flag_delay0);        // get the posedge of st_done_flag to generate "st_done" one pulse

        // state machine transfer
        always @(posedge dri_clk, negedge sys_rst_n) begin
                if(!sys_rst_n) begin
                        curr_state      <= st_idle;
                        next_state      <= st_idle;
                end
                else begin
                        curr_state      <= next_state;
                end
        end

//-------------------------------------------------------------------------------- state machine combinational logic
        always @(*) begin
                case(curr_state)
                        st_idle:        begin
                                if(op_exec_tap)         next_state      = st_pre;
                                else                    next_state      = st_idle;
                        end
                        st_pre:         begin
                                if(st_done)             next_state      = st_start;
                                else                    next_state      = st_pre;
                        end
                        st_start:       begin
                                if(st_done)             next_state      = st_addr;
                                else                    next_state      = st_start;
                        end
                        st_addr:        begin
                                if(st_done)             next_state      = reg_rh_wl ? st_rd_data : st_wr_data;
                                else                    next_state      = st_addr;
                        end
                        st_wr_data:     begin
                                if(st_done)             next_state      = st_idle;
                                else                    next_state      = st_wr_data;
                        end
                        st_rd_data:     begin
                                if(op_done)             next_state      = st_idle;
                                else                    next_state      = st_rd_data;
                        end
                endcase
        end

//-------------------------------------------------------------------------------- state machine sequential logic output
        
        // reg define
        reg             reg_op_done;
        reg             reg_op_ack;
        reg[15:0]       reg_op_rd_data;         // the data(16-bit) be read out
        reg             reg_op_rd_ack;          // the ack flag generated by slave phy

        wire    in_mdio;                                        // to receive data 
        reg     out_mdio;                                       // to send data
        reg     mdio_dir;                                       // contrl the operation(receive or send)
        
        assign  eth_mdio   = mdio_dir ? out_mdio : 1'bz;        // realize direction of operation
        assign  in_mdio    = eth_mdio;                          // realize receive data
        
        assign  op_rd_data = reg_op_rd_data;                    // output logic
        assign  op_done    = reg_op_done;                       // output logic
        assign  op_rd_ack  = reg_op_ack;                        // output logic

        
        reg[4:0]        bit_cnt;                                // counting operation data position

        // sequential logic output
        always @(posedge dri_clk, negedge sys_rst_n) begin
                if(!sys_rst_n) begin
                        reg_op_done     <= 1'b0;
                        reg_op_ack      <= 1'b0;
                        reg_op_rd_data  <= 16'b0;
                        reg_op_rd_ack   <= 1'b0;
                        mdio_dir        <= 1'b0;
                        out_mdio        <= 1'b0;  

                        bit_cnt         <= 5'b0;    
                        reg_op_done     <= 1'b0;
                        st_done_flag    <= 1'b0;    
                end
                else begin
                        case(curr_state) 
                                st_idle:        begin
                                        reg_op_done     <= 1'b0;
                                        reg_op_rd_data  <= 1'b0;
                                        reg_op_rd_ack   <= 1'b0;
                                        mdio_dir        <= 1'b0;

                                        bit_cnt         <= 5'b0;
                                        reg_op_done     <= 1'b0;
                                end
                                st_pre:         begin
                                        mdio_dir        <= 1'b1;
                                        st_done_flag    <= 1'b0;

                                        if(dri_clk ^ eth_mdc) begin     // negedge eth_dmc
                                                bit_cnt   <= bit_cnt+1;
                                                case(bit_cnt)
                                                        5'd0:   out_mdio <= 1'b1;
                                                        5'd1:   out_mdio <= 1'b1;
                                                        5'd2:   out_mdio <= 1'b1;
                                                        5'd3:   out_mdio <= 1'b1;

                                                        5'd4:   out_mdio <= 1'b1;
                                                        5'd5:   out_mdio <= 1'b1;
                                                        5'd6:   out_mdio <= 1'b1;
                                                        5'd7:   out_mdio <= 1'b1;

                                                        5'd8:   out_mdio <= 1'b1;
                                                        5'd9:   out_mdio <= 1'b1;
                                                        5'd10:  out_mdio <= 1'b1;
                                                        5'd11:  out_mdio <= 1'b1;

                                                        5'd12:  out_mdio <= 1'b1;
                                                        5'd13:  out_mdio <= 1'b1;
                                                        5'd14:  out_mdio <= 1'b1;
                                                        5'd15: begin  
                                                                out_mdio        <= 1'b1;
                                                                bit_cnt         <= 5'b0;
                                                                st_done_flag    <= 1'b1;
                                                        end
                                                endcase  
                                        end
                                end
                                st_start:       begin
                                        mdio_dir        <= 1'b1;
                                        st_done_flag    <= 1'b0;

                                        if(dri_clk ^ eth_mdc) begin     // negedge eth_dmc
                                                bit_cnt <= bit_cnt+1;
                                                case(bit_cnt)
                                                        // start signal
                                                        5'd0:   out_mdio <= 1'b0;
                                                        5'd1:   out_mdio <= 1'b1;
                                                        // operation contrl
                                                        5'd2:   out_mdio <= op_code[1];
                                                        5'd3: begin
                                                                out_mdio        <= op_code[0];
                                                                bit_cnt         <= 5'b0;
                                                                st_done_flag    <= 1'b1;
                                                        end
                                                endcase
                                        end
                                end
                                st_addr:        begin
                                        mdio_dir        <= 1'b1;
                                        st_done_flag    <= 1'b0;
                                        
                                        if(dri_clk ^ eth_mdc) begin
                                                bit_cnt <= bit_cnt+1;
                                                case(bit_cnt)
                                                        // PHY address
                                                        5'd0:   out_mdio <= PHY_ADDR[4];
                                                        5'd1:   out_mdio <= PHY_ADDR[3];
                                                        5'd2:   out_mdio <= PHY_ADDR[2];
                                                        5'd3:   out_mdio <= PHY_ADDR[1];
                                                        5'd4:   out_mdio <= PHY_ADDR[0];
                                                        // REG  address
                                                        5'd5:   out_mdio <= reg_op_addr[4];
                                                        5'd6:   out_mdio <= reg_op_addr[3];
                                                        5'd7:   out_mdio <= reg_op_addr[2];
                                                        5'd8:   out_mdio <= reg_op_addr[1];
                                                        5'd9: begin   
                                                                out_mdio        <= reg_op_addr[0];
                                                                bit_cnt         <= 5'b0;
                                                                st_done_flag    <= 1'b1;
                                                        end
                                                endcase
                                        end
                                end
                                st_wr_data:     begin
                                        mdio_dir        <= 1'b1;
                                        st_done_flag    <= 1'b0;

                                        if(dri_clk ^ eth_mdc) begin
                                                bit_cnt <= bit_cnt+1;
                                                case(bit_cnt)
                                                        // TA
                                                        5'b0:   out_mdio <= 1'b1;
                                                        5'b1:   out_mdio <= 1'b0;
                                                        // write in data
                                                        5'd2:   out_mdio <= reg_wr_data[15];
                                                        5'd3:   out_mdio <= reg_wr_data[14];
                                                        5'd4:   out_mdio <= reg_wr_data[13];
                                                        5'd5:   out_mdio <= reg_wr_data[12];

                                                        5'd6:   out_mdio <= reg_wr_data[11];
                                                        5'd7:   out_mdio <= reg_wr_data[10];
                                                        5'd8:   out_mdio <= reg_wr_data[9];
                                                        5'd9:   out_mdio <= reg_wr_data[8];

                                                        5'd10:  out_mdio <= reg_wr_data[7];
                                                        5'd11:  out_mdio <= reg_wr_data[6];
                                                        5'd12:  out_mdio <= reg_wr_data[5];
                                                        5'd13:  out_mdio <= reg_wr_data[4];

                                                        5'd14:  out_mdio <= reg_wr_data[3];
                                                        5'd15:  out_mdio <= reg_wr_data[2];
                                                        5'd16:  out_mdio <= reg_wr_data[1];
                                                        5'd17: begin  
                                                                out_mdio        <= reg_wr_data[0];
                                                                st_done_flag    <= 1'b1;
                                                                bit_cnt         <= 5'b0;

                                                                reg_op_done     <= 1'b1;
                                                        end
                                                endcase
                                        end
                                end
                                st_rd_data:     begin
                                        st_done_flag    <= 1'b0;

                                        if((dri_clk ^ eth_mdc) && (bit_cnt==5'd0)) begin
                                                mdio_dir        <= 1'b0;
                                                bit_cnt         <= bit_cnt + 1;
                                        end
                                        else if(dri_clk ~^ eth_mdc) begin
                                                bit_cnt <= bit_cnt + 1;
                                                case(bit_cnt) 
                                                        5'd2: begin
                                                                if(in_mdio == 1'b0)     reg_op_ack <= 1'b1;
                                                        end   

                                                        5'd3:   reg_op_rd_data[15] <= in_mdio;
                                                        5'd4:   reg_op_rd_data[14] <= in_mdio;
                                                        5'd5:   reg_op_rd_data[13] <= in_mdio;
                                                        5'd6:   reg_op_rd_data[12] <= in_mdio;

                                                        5'd7:   reg_op_rd_data[11] <= in_mdio;
                                                        5'd8:   reg_op_rd_data[10] <= in_mdio;
                                                        5'd9:   reg_op_rd_data[ 9] <= in_mdio;
                                                        5'd10:  reg_op_rd_data[ 8] <= in_mdio;

                                                        5'd11:  reg_op_rd_data[ 7] <= in_mdio;
                                                        5'd12:  reg_op_rd_data[ 6] <= in_mdio;
                                                        5'd13:  reg_op_rd_data[ 5] <= in_mdio;
                                                        5'd14:  reg_op_rd_data[ 4] <= in_mdio;

                                                        5'd15:  reg_op_rd_data[ 3] <= in_mdio;
                                                        5'd16:  reg_op_rd_data[ 2] <= in_mdio;
                                                        5'd17:  reg_op_rd_data[ 1] <= in_mdio;
                                                        5'd18: begin  
                                                                st_done_flag       <= 1'b1;     
                                                                reg_op_rd_data[ 0] <= in_mdio;
                                                                bit_cnt            <= 5'b0;
                                                                reg_op_done        <= 1'b1;
                                                                reg_op_ack         <= 1'b0;
                                                        end
                                                endcase
                                        end
                                end
                        endcase
                end
        end

endmodule

