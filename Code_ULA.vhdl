LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

--anti_debounce section is resposible for solving the debouncing problem from the input button

--INs:
--clk is going to be connected to the clk2 state_machine parameter
--debounced_signal is the noisy button input

--OUTs:
--filtered is the final filtered signal

--definition of anti_debounce entity
ENTITY anti_debounce IS
	PORT(
	clk : IN STD_LOGIC;
	debounced_signal : IN STD_LOGIC;
	filtered : OUT STD_LOGIC
	);
END anti_debounce;


--definition of anti_debounce logic
ARCHITECTURE debounce_logic OF anti_debounce IS

	--N is a really huge number that will help to count time in ms scale
	CONSTANT N : INTEGER := 19;
	
	--q_reg and q_next will count N really fast
	SIGNAL q_reg, q_next : UNSIGNED( N-1 downto 0) := (others => '0');

	--m_tick is a flag that says that N is completely counted
	SIGNAL m_tick : STD_LOGIC;

	--state_type defines types of state
	TYPE state_type IS ( zero, wait1_1, wait1_2, wait1_3, one, wait0_1, wait0_2, wait0_3);

	--state_reg and state_next are the now and next states of the debouncing circuit
	SIGNAL state_reg, state_next : state_type;
	BEGIN
		--initiates a sequencial process
		PROCESS(clk)
		BEGIN
			--everytime the Clock pulses, q_reg receives q_next, increasing the counter
			IF (clk'event AND CLK='1') THEN
				q_reg <= q_next;
			END IF;
		END PROCESS; 

		--connects q_next always to q_reg + 1
		q_next <= q_reg + 1;

		--detects if the counting finally reached the N amount, that is a few ms
		m_tick <= '1' WHEN q_reg = (2*N - 1) ELSE '0';

		--initiates a sequencial process
		PROCESS(CLK)
		BEGIN
			--when clock pulses, the current state is receives that next state
			IF (clk'event AND CLK='1') THEN
				state_reg <= state_next;
			END IF;
		END PROCESS;

		--initiates a sequential process
		PROCESS(state_reg, debounced_signal, m_tick)
		BEGIN
			filtered <= '0';
			state_next <= state_reg;

			--detects which state the debouncing circuit currently is
			CASE state_reg IS
				--if the button is pressed, the estability verification starts
				WHEN zero =>
					IF debounced_signal='1' THEN
						state_next <= wait1_1;
					END IF;
				--if anytime before the N counter is done the input is '0', the
				--verification resets. That says that there was a short amount of
				--time where the signal trembled. This process is done 3 times in a row.
				WHEN wait1_1 =>
					IF debounced_signal='0' THEN
						state_next <= zero;
					ELSE
						IF m_tick='1' THEN
							state_next <= wait1_2;
						END IF;
					END IF;
				WHEN wait1_2 =>
					IF debounced_signal='0' THEN
						state_next <= zero;
					ELSE
						IF m_tick='1' THEN
							state_next <= wait1_3;
						END IF;
					END IF;
				WHEN wait1_3 =>
					IF debounced_signal='0' THEN
						state_next <= zero;
					ELSE
						IF m_tick='1' THEN
							state_next <= one;
						END IF;
					END IF;
				--If the stability is finally confirmed, the filtered output,
				--is changed to 1.
				WHEN one =>
					filtered <= '1';
					IF debounced_signal='0' THEN
						state_next <= wait0_1;
					END IF;
				--The same process is done again, but to verify if the button
				--is no longer pressed.
				WHEN wait0_1 =>
					filtered <= '1';
					IF debounced_signal='1' THEN
						state_next <= one;
					ELSE
						IF m_tick='1' THEN
							state_next <= wait0_2;
						END IF;
					END IF;
				WHEN wait0_2 =>
					filtered <= '1';
					IF debounced_signal='1' THEN
						state_next <= one;
					ELSE
						IF m_tick='1' THEN
							state_next <= wait0_3;
						END IF;
					END IF;
				WHEN wait0_3 =>
					filtered <= '1';
					IF debounced_signal='1' THEN
						state_next <= one;
					ELSE
						IF m_tick='1' THEN
							state_next <= zero;
						END IF;
					END IF;
				END CASE;
			END PROCESS;
		END debounce_logic;

--------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;

--The entity MUX is responsible for receiving the inputs from the user
--and for filtering the output of the respective operation told by the user.

--INs:
--inputN represents the 4bit input levers used to define the operation and operands.
--clk5 represents the clock used for state changing
--BUTTON_CLOCK4 is the button used to switch between states by the used (operation, operand1, operand2, output)
--OUTs:
--yN represents the 4bit output LEDs that shows the result of the operation done.
--carry_out represents a LED that says if there's a carry out
--ov represents a LED that says if there's an overflow
--N represents a LED that says if the result is negative
--Z represents a LED that says if the result is zero


--Definition of entity MUX
ENTITY MUX IS
	PORT(
		input3, input2, input1, input0, clk5, BUTTON_CLOCK4 : IN STD_LOGIC;
		y3, y2, y1, y0, carry_out, ov, N, Z : OUT STD_LOGIC
	);
END MUX;

--Logic of entity MUX
ARCHITECTURE MUX_logic OF MUX IS

	--Selector of MUX
	SIGNAL selector : STD_LOGIC_VECTOR(2 downto 0);

	--Enable of MUX
	SIGNAL enable : STD_LOGIC;

	--parameters from operations_section component
	SIGNAL overflow_compare : STD_LOGIC;
	SIGNAL negative_compare : STD_LOGIC;
	SIGNAL carry_compare, carry_compare2 : STD_LOGIC;

	--parameters that y"N" will receive
	SIGNAL out0, out1, out2, out3 : STD_LOGIC;

	--z is a SIGNAL where the number represents its operation:
	--1: Sum or Sub of complement of 2
	--3: 4bits AND
	--4: 4bits OR
	--5: 4bits XOR
	--6: 4bits XNOR
	--7: shift
	--8: roll
	--and the letter represents the corresponding bit, "a" being the LSB and "d" the MSB
	--EX: za1 is the LSB of the sum result, zb3 is the 3th bit of 4bits AND op
	SIGNAL za1, za3, za4, za7, za8, za5, za6, zb1, zb3, zb4, zb5, zb6, zb7, zb8,
	zc1, zc3, zc4, zc5, zc6, zc7, zc8, zd1, zd7, zd3, zd4, zd5, zd6, zd8 : STD_LOGIC;

	--Component operations_section that'll be discussed later
	COMPONENT operations_section
		PORT(
		x0, x1, x2, x3, clk4, BUTTON3 : IN STD_LOGIC;
		and_out, or_out, xor_out, xnor_out : out STD_LOGIC_VECTOR(3 downto 0);
		op0, op1, op2, output_state : OUT STD_LOGIC;
		Result_sumsub   : out STD_LOGIC_VECTOR (3 downto 0);
        	Cout     : out STD_LOGIC;
        	Overflow : out STD_LOGIC;
        	Negative : out STD_LOGIC;
		Shift : out STD_LOGIC_VECTOR (4 downto 0);
		roll : out STD_LOGIC_VECTOR (3 downto 0)
		);
	END COMPONENT;
	BEGIN
			--connecting each bit of the output to the corresponding selected operation:
			out0 <= '0' WHEN enable = '0' ELSE
				za1 WHEN (selector = "000" OR selector = "001") ELSE
				za3 WHEN (selector = "010") ELSE
				za4 WHEN (selector = "011") ELSE
				za5 WHEN (selector = "100") ELSE
				za6 WHEN (selector = "101") ELSE
				za7 WHEN (selector = "110") ELSE
				za8;
			out1 <= '0' WHEN enable = '0' ELSE
				zb1 WHEN (selector = "000" OR selector = "001") ELSE
				zb3 WHEN (selector = "010") ELSE
				zb4 WHEN (selector = "011") ELSE
				zb5 WHEN (selector = "100") ELSE
				zb6 WHEN (selector = "101") ELSE
				zb7 WHEN (selector = "110") ELSE
				zb8;
			out2 <= '0' WHEN enable = '0' ELSE
				zc1 WHEN (selector = "000" OR selector = "001") ELSE
				zc3 WHEN (selector = "010") ELSE
				zc4 WHEN (selector = "011") ELSE
				zc5 WHEN (selector = "100") ELSE
				zc6 WHEN (selector = "101") ELSE
				zc7 WHEN (selector = "110") ELSE
				zc8;
			out3 <= '0' WHEN enable = '0' ELSE
				zd1 WHEN (selector = "000" OR selector = "001") ELSE
				zd3 WHEN (selector = "010") ELSE
				zd4 WHEN (selector = "011") ELSE
				zd5 WHEN (selector = "100") ELSE
				zd6 WHEN (selector = "101") ELSE
				zd7 WHEN (selector = "110") ELSE
				zd8;

			--Zero if every output is equal to 0

			Z <= '0' WHEN enable = '0' ELSE
				(NOT out3) AND (NOT out2) AND (NOT out1) AND (NOT out0);

			--Negative and overflow is only available only on sum and sub

			N <= '0' WHEN enable = '0' ELSE
				negative_compare WHEN (selector = "000" OR selector = "001") ELSE
				'0';

			Ov <= '0' WHEN enable = '0' ELSE
				overflow_compare WHEN (selector = "000" OR selector = "001") ELSE
				'0';

			--Carry_out is only available on sum, sub and shift

			carry_out <= '0' WHEN enable = '0' ELSE
				carry_compare WHEN (selector = "000" OR selector = "001") ELSE
				carry_compare2 WHEN selector = "110" ELSE
				'0';

			--connecting outputs to the out parameters

			y0 <= out0;
			y1 <= out1;
			y2 <= out2;
			y3 <= out3;


		--interconnecting component's signals to MUX signal

		instance4 : operations_section PORT MAP (
			x0 => input0,
			x1 => input1,
			x2 => input2,
			x3 => input3,
			
			clk4 => clk5,
			BUTTON3 => BUTTON_CLOCK4,
			and_out(0) => za3,
			and_out(1) => zb3,
			and_out(2) => zc3,
			and_out(3) => zd3,
			or_out(0) => za4,
			or_out(1) => zb4,
			or_out(2) => zc4,
			or_out(3) => zd4,
			xor_out(0) => za5,
			xor_out(1) => zb5,
			xor_out(2) => zc5,
			xor_out(3) => zd5,
			xnor_out(0) => za6,
			xnor_out(1) => zb6,
			xnor_out(2) => zc6,
			xnor_out(3) => zd6,
			op0 => selector(0),
			op1 => selector(1),
			op2 => selector(2),
			output_state => enable,
			result_sumsub(0) => za1,
			result_sumsub(1) => zb1,
			result_sumsub(2) => zc1,
			result_sumsub(3) => zd1,
			shift(0) => za7,
			shift(1) => zb7,
			shift(2) => zc7,
			shift(3) => zd7,
			shift(4) => carry_compare2,
			roll(0) => za8,
			roll(1) => zb8,
			roll(2) => zc8,
			roll(3) => zd8,
			overflow => overflow_compare,
			negative => negative_compare,
			Cout => carry_compare
			);

	END MUX_logic;
--------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

--The operations_section entity is responsible to define how each operation works.
--The operations are complement of 2 sum, complement of 2 sub, and, or, xor, xnor,
--shift and roll

--INs:
--clk4, BUTTON3 are going to be connected to clk5, BUTTON_CLOCK4 MUX parameters
--xN are connected to the user lever inputs

--OUTs:
--and_out, or_out, xor_out, xnor_out are 4 bits vector output of the logic gates operations
--op0, op1, op2 are the bits that define which operation is being done, that is
--connect to the MUX selector
--output_state is a flag that says if the circuit reached its output state (enable from MUX)
--result_sumsub is the output of complement of 2 sum or sub
--Cout, overflow, Negative are flags of carry_out, overflow and negative
--Shift is the output of shift operation
--roll is the output of roll operation


--definition of operations_section entity

ENTITY operations_section IS
	PORT(
		x0, x1, x2, x3, clk4, BUTTON3 : IN STD_LOGIC;
		and_out, or_out, xor_out, xnor_out : OUT STD_LOGIC_VECTOR(3 downto 0);
		op0, op1, op2, output_state : OUT STD_LOGIC;
        	Result_sumsub   : out STD_LOGIC_VECTOR (3 downto 0);
        	Cout     : out STD_LOGIC;
        	Overflow : out STD_LOGIC;
        	Negative : out STD_LOGIC;
		Shift : out STD_LOGIC_VECTOR (4 downto 0);
		Roll : out STD_LOGIC_VECTOR (3 downto 0)
	);
END operations_section;

--definition of operations_section logic

ARCHITECTURE logic_operations_section OF operations_section IS

	--B_eff will be used as a inverted bits input
	signal B_eff    : STD_LOGIC_VECTOR(3 downto 0);

	--operatorN receives which operation is being done.
	signal operator0, operator1, operator2 : STD_LOGIC;

	--A receives the first operand
	signal A        : STD_LOGIC_VECTOR (3 downto 0);

	--B receives the second operand
       	signal B        : STD_LOGIC_VECTOR (3 downto 0);

	--Sum_ext will be the result of the sum/sub (with carry in, made of 5bits)
    	signal Sum_ext  : UNSIGNED(4 downto 0);

	--Res_temp will be a convertion of Sum_ext in a 4 bits vector
    	signal Res_temp : STD_LOGIC_VECTOR(3 downto 0);

	--Cin_vec represents a carryIn in case of subtraction
    	signal Cin_vec  : UNSIGNED(4 downto 0);

	--Cin_shift is a 5bits vector to represent the shift with carry_out
	signal Cin_shift  : STD_LOGIC_VECTOR(4 downto 0);

	--component operation_selector will be discussed later
	COMPONENT operation_selector
		PORT(
		a0, a1, a2, a3, clk3, BUTTON2 : IN STD_LOGIC;
		o0, o1, o2, c0, c1, c2, c3, d0, d1, d2, d3, s : OUT STD_LOGIC
		);
	END COMPONENT;
	BEGIN

--LOGIC GATES SECTION
		--logic outputs receive the logic operations
		and_out <= A AND B;
		or_out <= A OR B;
		xor_out <= A XOR B;
		xnor_out <= A XNOR B;

------------------------------------

--SUM AND SUB SECTION

--verifies if it's a subtraction operation. If it is inverts the bits of second operand
--also, a carryIn is added to convert from negative to positive or the other way around.
    B_eff <= B xor (operator0 & operator0 & operator0 & operator0);
    Cin_vec <= "0000" & operator0;

--the operation of sum or sub
    Sum_ext <= unsigned('0' & A) + unsigned('0' & B_eff) + Cin_vec;

--convertion to a 4bit vector
    Res_temp <= std_logic_vector(Sum_ext(3 downto 0));
	 
	 op2 <= operator2;
	 op1 <= operator1;
	 op0 <= operator0;

--final result of sum or subtraction
    Result_sumsub  <= Res_temp;

--receives the carry out from the operation of sum/sub
    Cout     <= std_logic(Sum_ext(4));

--Verifies if there's an overflow by comparing the carries
    Overflow <= (A(3) xnor B_eff(3)) and (A(3) xor Res_temp(3));

--Verifies if the result is negative
    Negative <= Res_temp(3);

------------------------------------------------------------------

--SHIFT AND ROLL SECTION

	--transforms the output to a 5bit vector in order to consider the carry out
	Cin_shift <= "0" & A;

	--Verifies how many shifts were done, said by the second operand
	Shift <= std_logic_vector(unsigned(Cin_shift) sll 0) WHEN (B = "0000") ELSE
		std_logic_vector(unsigned(Cin_shift) sll 1) WHEN (B = "0001") ELSE
		std_logic_vector(unsigned(Cin_shift) sll 2) WHEN (B = "0010") ELSE
		std_logic_vector(unsigned(Cin_shift) sll 3) WHEN (B = "0011") ELSE
		std_logic_vector(unsigned(Cin_shift) sll 4) WHEN (B = "0100") ELSE
		std_logic_vector(unsigned(Cin_shift) sll 0) WHEN (B = "1000") ELSE
		std_logic_vector(unsigned(Cin_shift) sll -1) WHEN (B = "1001") ELSE
		std_logic_vector(unsigned(Cin_shift) sll -2) WHEN (B = "1010") ELSE
		std_logic_vector(unsigned(Cin_shift) sll -3) WHEN (B = "1011") ELSE
		"00000";

	--Verifies how many rolls were done, said by the second operand
	Roll <= std_logic_vector(unsigned(A) rol 0) WHEN (B = "0000") ELSE
		std_logic_vector(unsigned(A) rol 1) WHEN (B = "0001") ELSE
		std_logic_vector(unsigned(A) rol 2) WHEN (B = "0010") ELSE
		std_logic_vector(unsigned(A) rol 3) WHEN (B = "0011") ELSE
		std_logic_vector(unsigned(A) rol 4) WHEN (B = "0100") ELSE
		std_logic_vector(unsigned(A) rol 5) WHEN (B = "0101") ELSE
		std_logic_vector(unsigned(A) rol 6) WHEN (B = "0110") ELSE
		std_logic_vector(unsigned(A) rol 7) WHEN (B = "0111") ELSE
		std_logic_vector(unsigned(A) rol 0) WHEN (B = "1000") ELSE
		std_logic_vector(unsigned(A) rol -1) WHEN (B = "1001") ELSE
		std_logic_vector(unsigned(A) rol -2) WHEN (B = "1010") ELSE
		std_logic_vector(unsigned(A) rol -3) WHEN (B = "1011") ELSE
		std_logic_vector(unsigned(A) rol -4) WHEN (B = "1100") ELSE
		std_logic_vector(unsigned(A) rol -5) WHEN (B = "1101") ELSE
		std_logic_vector(unsigned(A) rol -6) WHEN (B = "1110") ELSE
		std_logic_vector(unsigned(A) rol -7) WHEN (B = "1111");

	
	--interconnecting component's signals to operations_section
	instance3 : operation_selector PORT MAP (
			c0 => A(0),
			c1 => A(1),
			c2 => A(2),
			c3 => A(3),
			d0 => B(0),
			d1 => B(1),
			d2 => B(2),
			d3 => B(3),
			a0 => x0,
			a1 => x1,
			a2 => x2,
			a3 => x3,
			clk3 => clk4,
			BUTTON2 => BUTTON3,
			o0 => operator0,
			o1 => operator1,
			o2 => operator2,
			s => output_state
			);
	END logic_operations_section;

------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;

--The operation_selector section is responsible for detecting which state the circuit
--is currently and to which state inputs the users input will be connected to
--(operation, operand1, operand2)

--INs:
--clk3, BUTTON2 are going to be connected to clk4, BUTTON3 operations_section parameters
--aN will be connected to the user's lever input

--OUTs:
--oN will represent which operation is being done:
--000: Sum, 001: Sub, 010: And, 011: Or, 100: Xor, 101: Xnor, 110: Shift, 111: Roll
--cN will represent the first operand
--dN will represent the second operand
--s is a flag that says if the circuit is on its output state

--definition of operation_selector entity
ENTITY operation_selector IS
	PORT(
	a0, a1, a2, a3, clk3, BUTTON2 : IN STD_LOGIC;
	c0, c1, c2, c3, s, o0, o1, o2, d0, d1, d2, d3 : OUT STD_LOGIC
	);
END operation_selector;

--logic of operation_selector entity
ARCHITECTURE selector_logic OF operation_selector IS

	--operatorN is related to each one of the operands
	SIGNAL operator1, operator2 : STD_LOGIC_VECTOR(3 downto 0);

	--define_operation is related to which operation is being done
	SIGNAL define_operation : STD_LOGIC_VECTOR(2 downto 0);

	--state_counter says which state the circuit is (operation, operand1, operand2, output)
	SIGNAL state_counter: STD_LOGIC_VECTOR(1 downto 0);

	--btn_edge and btn_prev are used for a clock behavior
	SIGNAL btn_edge : STD_LOGIC := '0';
	SIGNAL btn_prev : STD_LOGIC := '0';

	--e1 and e2 are connected to the state_machine component
	SIGNAL e1, e2 : STD_LOGIC;

	--the state_machine component will be discussed later
	COMPONENT state_machine
		PORT(
		CLK2 : IN STD_LOGIC;
		BUTTON : IN STD_LOGIC;
		A : OUT STD_LOGIC;
		B : OUT STD_LOGIC
		);
	END COMPONENT;
	BEGIN
		--connects state_counter to the states from the state_machine
		state_counter <= e2 & e1;

		--initiate a sequential process
		PROCESS(e1, e2, clk3)
		BEGIN
			--Changes state if detects clock and button pressed
			IF FALLING_EDGE(CLK3) THEN
				btn_edge <= BUTTON2 AND NOT btn_prev;
				btn_prev <= BUTTON2;
				IF btn_edge = '1' THEN

					--if state is 00 (operation), aN is connected to define_operation
					IF(state_counter = "00") THEN
						define_operation <= a2 & a1 & a0;
						operator1 <= "0000";
						operator2 <= "0000";
						s <= '0';

					--if state is 01 (operand1), aN is connected to operator1
					ELSIF(state_counter =  "01") THEN
						operator1 <= a3 & a2 & a1 & a0;
					--if state is 11 (operand2), aN is connected to operator2
					ELSIF(state_counter = "11") THEN
						operator2 <= a3 & a2 & a1 & a0;
					--if state is 10 (output), the s flag is activated (enable)
					ELSIF(state_counter = "10") THEN
						s <= '1';
					END IF;
				END IF;
			END IF;
		END PROCESS;

		--lastly, the outputs are connected to the logic parameters
		o0 <= define_operation(0);
		o1 <= define_operation(1);
		o2 <= define_operation(2);
		c0 <= operator1(0);
		c1 <= operator1(1);
		c2 <= operator1(2);
		c3 <= operator1(3);
		
		d0 <= operator2(0);
		d1 <= operator2(1);
		d2 <= operator2(2);
		d3 <= operator2(3);
		
		--interconnecting component's signals to operation_selector signals
		instance2 : state_machine PORT MAP (
			BUTTON => BUTTON2,
			A => e1,
			B => e2,
			CLK2 => CLK3
			);
			
	END selector_logic; 

-----------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;

--state_machine is responsible for changing the states of the circuit

--INs:
--clk2, BUTTON are going to be connected to clk3, BUTTON2 operation_selector parameters

--OUTs:
--BA is a vector that identifies which state the circuit is

--definition of state_machine entity
ENTITY state_machine IS
	PORT(
	CLK2 : IN STD_LOGIC;
	BUTTON : IN STD_LOGIC;
	A : OUT STD_LOGIC;
	B : OUT STD_LOGIC
	);
END state_machine;

--logic of state_machine entity
ARCHITECTURE machine_logic OF state_machine IS
	--component anti_debounce will be discussed later
	COMPONENT anti_debounce 
	PORT(
		CLK : IN STD_LOGIC;
		debounced_signal : IN STD_LOGIC;
		filtered : OUT STD_LOGIC
		);
	END COMPONENT;

	--type state to represent the possible states of the circuits
	TYPE state IS (operation, enter1, enter2, final_state);

	--state that the circuit is now
	SIGNAL state_now : state := final_state;

	--used as parameter to define state_now
	SIGNAL state_counter: STD_LOGIC_VECTOR(1 downto 0);

	--btn_edge and btn_prev are used for a clock behavior
	SIGNAL btn_prev : STD_LOGIC := '0';
	SIGNAL btn_edge : STD_LOGIC := '0';

	--filtered_pulse is the filtered input button pulse, that is responsible for
	--changing the states
	SIGNAL filtered_pulse : STD_LOGIC;

	BEGIN
		--initiates a sequential process
		PROCESS(CLK2)
		BEGIN
			--detects if the button were pressed
			IF RISING_EDGE(CLK2) THEN
					btn_edge <= filtered_pulse AND NOT btn_prev;
					btn_prev <= filtered_pulse;
				
					IF btn_edge = '1' THEN
						--changes state to the next state
						IF state_now=operation THEN
							state_now <= enter1;
						ELSIF state_now=enter1 THEN
							state_now <= enter2;
						ELSIF state_now=enter2 THEN
							state_now  <= final_state;
						ELSIF state_now=final_state THEN
							state_now <= operation;
						END IF;
					END IF;
				END IF;
		END PROCESS;

		--identifies state_counter
		state_counter <= "00" WHEN state_now=operation ELSE
					"01" WHEN state_now=enter1 ELSE
					"11" WHEN state_now=enter2 ELSE
					"10";

		--outputs that receive the state now
		A <= state_counter(0);
		B <= state_counter(1);

		--interconnecting component's signals to state_machine signals
		instance : anti_debounce PORT MAP (
			debounced_signal => BUTTON,
			CLK => CLK2,
			filtered => filtered_pulse
			);
	END machine_logic;
