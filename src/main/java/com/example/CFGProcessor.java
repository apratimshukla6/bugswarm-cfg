package com.example;

import spoon.processing.AbstractProcessor;
import spoon.reflect.code.*;
import spoon.reflect.declaration.CtClass;
import spoon.reflect.declaration.CtMethod;

import java.io.FileWriter;
import java.io.IOException;
import java.util.LinkedHashSet;
import java.util.Set;

public class CFGProcessor extends AbstractProcessor<CtMethod<?>> {

    private StringBuilder graph = new StringBuilder();
    private Set<CtMethod<?>> processedMethods = new LinkedHashSet<>();
    private String lastNodeName = "start";

    public CFGProcessor() {
        graph.append("digraph CFG {\n");
        graph.append("    start [label=\"Start\"];\n"); // Define the start node
    }

    @Override
    public boolean isToBeProcessed(CtMethod<?> candidate) {
        // Ensure processing only for methods in the App class
        return candidate.getParent(CtClass.class) != null
                && "App".equals(candidate.getParent(CtClass.class).getSimpleName());
    }

    @Override
    public void process(CtMethod<?> method) {
        if (processedMethods.add(method)) {
            // Add a node for the method itself
            String methodName = method.getSimpleName();
            String methodNodeName = "method_" + methodName;
            graph.append(String.format("    %s [label=\"%s Method\"];\n", methodNodeName, methodName));
            addEdge(lastNodeName, methodNodeName);
            lastNodeName = methodNodeName;

            // Process each statement in the method
            method.getBody().getStatements().forEach(this::processStatement);
        }
    }

    private void processStatement(CtStatement statement) {
        if (statement instanceof CtIf) {
            processIf((CtIf) statement);
        } else if (statement instanceof CtSwitch) {
            processSwitch((CtSwitch<?>) statement);
        } else if (statement instanceof CtLoop) {
            processLoop((CtLoop) statement);
        } else {
            String statementLabel = getStatementLabel(statement);
            String statementNodeName = "stmt_" + System.identityHashCode(statement);
            graph.append(String.format("    %s [label=\"%s\"];\n", statementNodeName, statementLabel));
            addEdge(lastNodeName, statementNodeName);
            lastNodeName = statementNodeName;
        }
    }


    private void processIf(CtIf ctIf) {
        String ifNodeName = "if_" + System.identityHashCode(ctIf);
        String endifNodeName = "endif_" + System.identityHashCode(ctIf);
        graph.append(String.format("    %s [label=\"If Condition\"];\n", ifNodeName));
        addEdge(lastNodeName, ifNodeName);

        // Process then part
        String tempLast = lastNodeName;
        lastNodeName = ifNodeName;
        CtStatement thenPart = ctIf.getThenStatement();
        if (thenPart != null) {
            processStatement(thenPart);
        }
        // Connect then part to end-if
        addEdge(lastNodeName, endifNodeName);

        // Process else part
        CtStatement elsePart = ctIf.getElseStatement();
        if (elsePart != null) {
            lastNodeName = ifNodeName; // Start else from if node
            String elseNodeName = "else_" + System.identityHashCode(ctIf);
            graph.append(String.format("    %s [label=\"Else\"];\n", elseNodeName));
            addEdge(ifNodeName, elseNodeName); // Connect if to else directly
            lastNodeName = elseNodeName;
            processStatement(elsePart);
            // Connect else part to end-if
            addEdge(lastNodeName, endifNodeName);
        } else {
            // Connect if directly to end-if if there's no else
            addEdge(ifNodeName, endifNodeName);
        }
        
        lastNodeName = endifNodeName; 
        graph.append(String.format("    %s [label=\"End If\"];\n", endifNodeName));
    }

    // Modified processLoop method to handle while, for, and do-while loops specifically
    private void processLoop(CtLoop loop) {
        if (loop instanceof CtWhile) {
            processWhile((CtWhile) loop);
        } else if (loop instanceof CtFor) {
            processFor((CtFor) loop);
        } else if (loop instanceof CtDo) {
            processDoWhile((CtDo) loop);
        }
    }

    private void processWhile(CtWhile ctWhile) {
        String whileNodeName = "while_" + System.identityHashCode(ctWhile);
        graph.append(String.format("    %s [label=\"While Condition\"];\n", whileNodeName));
        addEdge(lastNodeName, whileNodeName); // Edge from the last node to the while condition

        // Process the while body
        lastNodeName = whileNodeName;
        processStatement(ctWhile.getBody());
        
        // Loop back to the while condition
        addEdge(lastNodeName, whileNodeName);
        String whileEndNodeName = "endwhile_" + System.identityHashCode(ctWhile);
        graph.append(String.format("    %s [label=\"End While\"];\n", whileEndNodeName));
        addEdge(whileNodeName, whileEndNodeName); // Add an edge to exit the loop

        lastNodeName = whileEndNodeName; // Continue from the end of the while
    }

    private void processFor(CtFor ctFor) {
        String forNodeName = "for_" + System.identityHashCode(ctFor);
        graph.append(String.format("    %s [label=\"For Loop\"];\n", forNodeName));
        addEdge(lastNodeName, forNodeName); // Edge from the last node to the for loop
        
        // Process the for body
        lastNodeName = forNodeName;
        processStatement(ctFor.getBody());

        // Loop back to the for condition (simulate the for loop's iteration)
        addEdge(lastNodeName, forNodeName);
        String forEndNodeName = "endfor_" + System.identityHashCode(ctFor);
        graph.append(String.format("    %s [label=\"End For\"];\n", forEndNodeName));
        addEdge(forNodeName, forEndNodeName); // Add an edge to exit the loop

        lastNodeName = forEndNodeName; // Continue from the end of the for loop
    }

    private void processDoWhile(CtDo ctDo) {
        String doNodeName = "do_" + System.identityHashCode(ctDo);
        graph.append(String.format("    %s [label=\"Do While\"];\n", doNodeName));
        addEdge(lastNodeName, doNodeName); // Edge from the last node to do

        // Process the do-while body
        lastNodeName = doNodeName;
        processStatement(ctDo.getBody());

        // Condition check at the end of do-while
        String doWhileCondNodeName = "doWhileCond_" + System.identityHashCode(ctDo);
        graph.append(String.format("    %s [label=\"Do While Condition\"];\n", doWhileCondNodeName));
        addEdge(lastNodeName, doWhileCondNodeName);
        
        // Loop back from condition to start of do-while
        addEdge(doWhileCondNodeName, doNodeName);
        String doWhileEndNodeName = "endDoWhile_" + System.identityHashCode(ctDo);
        graph.append(String.format("    %s [label=\"End Do While\"];\n", doWhileEndNodeName));
        
        // Add an edge to exit the loop
        addEdge(doWhileCondNodeName, doWhileEndNodeName);
        lastNodeName = doWhileEndNodeName; // Continue from the end of the do-while loop
    }

    // Process Switch statements
    private void processSwitch(CtSwitch<?> ctSwitch) {
        String switchNodeName = "switch_" + System.identityHashCode(ctSwitch);
        String endSwitchNodeName = "endswitch_" + System.identityHashCode(ctSwitch);
        graph.append(String.format("    %s [label=\"Switch\"];\n", switchNodeName));
        addEdge(lastNodeName, switchNodeName);

        ctSwitch.getCases().forEach(caseStatement -> {
            String caseNodeName = "case_" + System.identityHashCode(caseStatement);
            graph.append(String.format("    %s [label=\"Case\"];\n", caseNodeName));
            addEdge(switchNodeName, caseNodeName);
            lastNodeName = caseNodeName;
            caseStatement.getStatements().forEach(this::processStatement);
            addEdge(lastNodeName, endSwitchNodeName); // Connect each case to the end-switch
        });

        lastNodeName = endSwitchNodeName; // Continue from the end-switch node
        graph.append(String.format("    %s [label=\"End Switch\"];\n", endSwitchNodeName));
    }
    

    @Override
    public void processingDone() {
        graph.append("    end [label=\"End\"];\n");
        addEdge(lastNodeName, "end");
        graph.append("}\n"); // Close the graph definition
        try (FileWriter writer = new FileWriter("cfg.dot")) {
            writer.write(graph.toString()); // Write the CFG to a file
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    private String getStatementLabel(CtStatement statement) {
        // Escape double quotes and control the length of the statement's string representation
        String label = statement.toString().replace("\"", "\\\"");
        // Shorten or format the label as needed to prevent overly long labels
        return label.length() > 50 ? label.substring(0, 47) + "..." : label;
    }

    private void addEdge(String from, String to) {
        graph.append(String.format("    %s -> %s;\n", from, to));
    }
}
