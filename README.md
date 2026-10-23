# Advanced Verilog FIFO Verification Environment

A robust, self-checking verification framework designed to thoroughly test and stress-test a classical synchronous FIFO architecture. 

## 📂 Project Structure & Attribution

* **`fifo.v` & `FIFO_MEM_BLK.v` (Design Core):** 
  * **Origin:** Textbook reference core.
  * **Author Attribution:** Originally developed by **Venkata Ramana Kalapatapu** at **Sand Microelectronics Inc. (now Synopsys, Inc.)**. Included here as the Design Under Test (DUT).
* **`tb_fifo.v` (Verification Environment — **Engineered by Me**):** 
  * **Description:** A custom-built, advanced self-checking testbench featuring an automated cycle-accurate reference scoreboard, protocol assertions, and constrained-random stress testing.

---

## 🚀 Highlights of the Testbench (`tb_fifo.v`)
* **Cycle-Accurate Reference Scoreboard:** Runs a shadow model parallel to the DUT to validate every push, pop, and dynamic data transfer.
* **Automated Flag Validation:** Continuously checks dynamic status flags (`F_EmptyN`, `F_FullN`, `F_FirstN`, `F_SLastN`, `F_LastN`) against expected queue states.
* **Constrained-Random Stress Suite:** Stress-tests the FIFO across thousands of mixed cycles (write-heavy, read-heavy, and balanced profiles).
* **Robust Error & Boundary Handling:** Validates core reactions to illegal operations (overflows/underflows) and asynchronous resets.
