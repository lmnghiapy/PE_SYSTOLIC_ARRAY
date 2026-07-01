`timescale 1ns/1ps

// =====================================================================
// Testbench cho bộ cộng FP16
// So sánh kết quả giữa phiên bản gốc (4-stage) và tối ưu (6-stage)
// =====================================================================

module tb_ei_adder_fp16;

    // 1. Khai báo tín hiệu
    reg clk;
    reg rst;
    reg en;
    
    reg [15:0] a_in;
    reg [15:0] b_in;
    
    wire [15:0] sum_out_v1; // Kết quả từ bản cũ (4 cycles)
    wire [15:0] sum_out_v2; // Kết quả từ bản mới (6 cycles)
    
    // 2. Tạo Clock (100MHz -> chu kỳ 10ns)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 3. Khởi tạo Module (DUT - Device Under Test)
    // Bản gốc - Golden Model
    ei_adder_fp16 dut_v1 (
        .sys_clk(clk),
        .rst(rst),
        .en(en),
        .a_in(a_in),
        .b_in(b_in),
        .sum_out(sum_out_v1)
    );
    
    // Bản tối ưu Fmax
    ei_adder_fp16_v2 dut_v2 (
        .sys_clk(clk),
        .rst(rst),
        .en(en),
        .a_in(a_in),
        .b_in(b_in),
        .sum_out(sum_out_v2)
    );
    
    // 4. Đồng bộ Pipeline (Cân bằng Latency)
    // Do bản cũ trễ 4 clock, bản mới trễ 6 clock
    // -> Ta cần delay kết quả bản cũ thêm 2 clock để so sánh đúng lúc
    reg [15:0] sum_v1_delay1;
    reg [15:0] sum_v1_delay2;
    
    always @(posedge clk) begin
        if (rst) begin
            sum_v1_delay1 <= 16'd0;
            sum_v1_delay2 <= 16'd0;
        end else if (en) begin
            sum_v1_delay1 <= sum_out_v1;
            sum_v1_delay2 <= sum_v1_delay1; // Giá trị delay 2 chu kỳ
        end
    end
    
    // 5. Kiểm tra tự động (Checker)
    integer err_count = 0;
    integer test_count = 0;
    
    // Lưu các input vào pipeline để in ra khi có lỗi
    reg [15:0] a_pipe [0:5];
    reg [15:0] b_pipe [0:5];
    integer i;

    wire is_v1_nan = (sum_v1_delay1[14:10] == 5'b11111 && sum_v1_delay1[9:0] != 0);
    wire is_v2_nan = (sum_out_v2[14:10] == 5'b11111 && sum_out_v2[9:0] != 0);

    always @(posedge clk) begin
        if (!rst && en) begin
            a_pipe[0] <= a_in;
            b_pipe[0] <= b_in;
            for (i = 0; i < 5; i = i + 1) begin
                a_pipe[i+1] <= a_pipe[i];
                b_pipe[i+1] <= b_pipe[i];
            end
            
            // Bắt đầu check sau khi pipeline đã được làm đầy
            if (test_count > 5) begin
                // Bỏ qua nếu cả 2 đều là NaN (do payload NaN có thể khác nhau tùy thiết kế)
                
                if (sum_v1_delay1 !== sum_out_v2 && !(is_v1_nan && is_v2_nan)) begin
                    $display("ERROR: a=%h b=%h | v1_out=%h v2_out=%h", a_pipe[4], b_pipe[4], sum_v1_delay1, sum_out_v2);
                    err_count = err_count + 1;
                end
            end
        end
    end
    
    // 6. Tạo Test Vector (Stimulus)
    initial begin
        // Reset hệ thống
        rst = 1;
        en = 0;
        a_in = 0;
        b_in = 0;
        
        #25;
        rst = 0;
        en = 1;
        
        $display("--- BẮT ĐẦU TEST: CORNER CASES ---");
        // Test 1: Zero
        a_in = 16'h0000; b_in = 16'h0000; test_count = test_count + 1; #10;
        // Test 2: Normal (1.0 + 1.0 = 2.0 -> 16'h4000)
        a_in = 16'h3C00; b_in = 16'h3C00; test_count = test_count + 1; #10;
        // Test 3: Khác dấu (1.0 - 1.0 = 0.0)
        a_in = 16'h3C00; b_in = 16'hBC00; test_count = test_count + 1; #10;
        // Test 4: +Inf và Normal
        a_in = 16'h7C00; b_in = 16'h3C00; test_count = test_count + 1; #10;
        // Test 5: NaN
        a_in = 16'h7E00; b_in = 16'h3C00; test_count = test_count + 1; #10;
        // Test 6: Underflow/Subnormal
        a_in = 16'h0001; b_in = 16'h0001; test_count = test_count + 1; #10;
        
        $display("--- BẮT ĐẦU TEST: 10,000 RANDOM VECTORS ---");
        repeat(10000) begin
            a_in = $random;
            b_in = $random;
            test_count = test_count + 1;
            #10;
        end
        
        // Đợi xả hết pipeline
        #100;
        
        if (err_count == 0)
            $display("======================================\nSUCCESS: TAT CA CAC TEST DEU PASS!\n======================================");
        else
            $display("======================================\nFAILED: Phat hien %0d loi.\n======================================", err_count);
            
        $finish;
    end
    
    // (Tùy chọn) Dump waveform để debug
    initial begin
        $dumpfile("tb_fp16.vcd");
        $dumpvars(0, tb_ei_adder_fp16);
    end

endmodule
