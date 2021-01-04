# ASM Labs
Laboratory works with Assembly (NASM) with Linux. Here you can find basic procedures to work with integer and floating point numbers, examples
of FPU using, implementing and using one and two dimensional arrays, simple macros. Programs don't use any extensions and written fully with x86 NASM on Linux.
## Tasks
1. Place reversed source to dest.
2. Read integer number from stdin. Substract 88 from given number. Write result to stdout.
3. Calculate function value depending on given X value (floating point) from stdin.
4. Implement functionality to read one or two dimensional integer array from stdin.\
Allow the following actions on given array:\
  4.1. Find sum of element of one dimensional array.\
  4.2. Find max element of one dimensional array.\
  4.3. Sort one dimensional array.\
  4.4. Find element indices in two dimensional array.
5. Rewrite tasks 2-4 using macro.
## How to use it
Primarily, allow execution for build.sh script
```
chmod +x build.sh
```
After that just build program you want to use
```
./build.sh [lab_number]
```
And, finally, run it
```
./labN/labN
```
## May be useful
*Points marked with FPU use FPU stack*
* **atoi** — convert string (ASCII) to integer.
* **itoa** — convert integer to ASII.
* **print_num** — print integer to stdout.
* **flush_stdin** — clear redundant data from stdin.
* **pow_10** — calculate 10^n value (FPU).
* **atof** — convert string (ASCII) to float (FPU).
* **normalize** — bring value to normal form with base 10 (FPU).
* **dtoa** — convert ASCII to double (FPU).
* **fpu2bcd2dec** — convert double to integer (FPU).
* **printf** — print floating point value to stdout (FPU).
* **print_str** — print given string to stdout (macro).
* **make_array** — create one dimensional array from stdin.
* **make_matrix** — create two dimensional array from stdin.
* **find_max** — find max element of one dimensional array.
* **find_sum** — find sum of elements of one dimensional array.
* **sort_array** — sort one dimensional array.
* **print_array** — print one dimensional array to stdout.
* **find_in_matrix** — find indices of given element from matrix.
## Related
* type conversion (float, integer, ASCII)
* FPU
* arrays
* macro
## Contributors
Vadym Kinchur, vvkin.
