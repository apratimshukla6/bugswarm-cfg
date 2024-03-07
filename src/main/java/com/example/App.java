package com.example;

public class App {
    // Method incorporating various operations, including a library function call
    public static int random(int i) {
        int result = 0;

        // Loop example: Summation using a for loop
        for (int j = 0; j < i; j++) {
            result += j;
        }

        // Switch statement example: Handling specific cases
        switch (i) {
            case 0:
                System.out.println("Zero");
                break;
            case 1:
                System.out.println("One");
                break;
            default:
                System.out.println("Other: " + i);
        }

        // Library function call: Calculating square using Math.pow
        double powerResult = Math.pow(i, 2);
        System.out.println("The square of " + i + " is: " + powerResult);

        // While loop example
        int whileCounter = 0;
        while (whileCounter < 2) {
            System.out.println("While loop count: " + whileCounter);
            whileCounter++;
        }

        // Do-While loop example
        int doWhileCounter = 0;
        do {
            System.out.println("Do-While loop count: " + doWhileCounter);
            doWhileCounter++;
        } while (doWhileCounter < 2);

        return result;
    }

    // Main method demonstrating various operations
    public static void main(String[] args) {
        // Loop example: Iterating to demonstrate various operations
        for (int i = 0; i < 5; i++) {
            int result = random(i);
            System.out.println("Result: " + result);
        }

        // Arithmetic operations: Simple addition
        int a = 10;
        int b = 20;
        int c = a + b;
        System.out.println("Sum: " + c);

        // Conditional example: Comparing values
        if (c > 15) {
            System.out.println("c is greater than 15");
        } else {
            System.out.println("c is not greater than 15");
        }

        // Final message
        System.out.println("Hello, World!");
    }
}

