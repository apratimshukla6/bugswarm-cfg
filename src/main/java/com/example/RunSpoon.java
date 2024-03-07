package com.example;

import spoon.Launcher;

public class RunSpoon {
    public static void main(String[] args) {
        Launcher launcher = new Launcher();
        launcher.addInputResource("src/main/java/com/example/");
        launcher.addProcessor(new CFGProcessor());
        launcher.run();
    }
}

