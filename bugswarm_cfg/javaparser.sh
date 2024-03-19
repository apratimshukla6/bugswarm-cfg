#!/bin/bash

start_time=$(date +%s) # Capture start time of the script

MAIN="/home/github"

# The first command line argument is used as the directory name
output_dir_name=$1
if [ -z "$output_dir_name" ]; then
    echo "Error: No directory name provided as an argument."
    exit 1
fi

# Step 1: Create the required directory structure and files
mkdir -p ${MAIN}/build/JavaParser/src/main/java/com/example
echo "Creating CFGProcessor.java..."
cat > ${MAIN}/build/JavaParser/src/main/java/com/example/CFGProcessor.java <<'EOF'
package com.example;

import com.github.javaparser.JavaParser;
import com.github.javaparser.ParseResult;
import com.github.javaparser.ast.CompilationUnit;
import com.github.javaparser.ast.body.MethodDeclaration;
import com.github.javaparser.ast.stmt.BlockStmt;
import com.github.javaparser.ast.stmt.ExpressionStmt;
import com.github.javaparser.ast.stmt.ForStmt;
import com.github.javaparser.ast.stmt.Statement;
import com.github.javaparser.ast.visitor.VoidVisitorAdapter;
import com.github.javaparser.ast.stmt.IfStmt;
import com.github.javaparser.ast.stmt.WhileStmt;
import com.github.javaparser.ast.stmt.DoStmt;
import com.github.javaparser.ast.stmt.SwitchStmt;
import com.github.javaparser.ast.stmt.SwitchEntry;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileWriter;
import java.io.IOException;
import java.util.HashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.ArrayList;

public class CFGProcessor {
    private static int nodeId = 1;
    private static final Map<String, MethodDeclaration> methodMap = new HashMap<>();
    private static final List<String> graphLines = new LinkedList<>();
    private final LinkedList<Integer> endNodeStack = new LinkedList<>();
    private static boolean isFirstMethod = true; // Add this flag

    public static void main(String[] args) {

        // Define the directory where Java files are located
        File dir = new File("src/main/java/com/example/");
        File[] files = dir.listFiles((d, name) -> name.endsWith(".java") && !name.equals("CFGProcessor.java"));

        if (files == null || files.length == 0) {
            System.out.println("No suitable Java files found.");
            return;
        }

        // Select the first Java file found (excluding CFGProcessor.java)
        File selectedFile = files[0];
        String filePath = selectedFile.getPath();

        try (FileInputStream in = new FileInputStream(filePath)) {

            ParseResult<CompilationUnit> parseResult = new JavaParser().parse(in);
            if (!parseResult.isSuccessful()) {
                throw new RuntimeException("Error parsing the file: " + filePath);
            }
            CompilationUnit cu = parseResult.getResult().get();

            graphLines.add("digraph G {");
            graphLines.add("\tnode0 [label=\"Start\"];"); // Initialize with a start node

            cu.accept(new DeclarationCollector(), null);

            // Process other methods if any
            methodMap.values().forEach(method -> {
                if (!method.getNameAsString().equals("main")) {
                    method.accept(new CFGVisitor(), null);
                }
            });

            if (methodMap.containsKey("main")) {
                graphLines.add("\tnode0 [label=\"Start\"];");
                // Directly connect the start node to the Main method node
                addNode("Method: main");
                methodMap.get("main").accept(new CFGVisitor(), null);
            }

            graphLines.add(String.format("\tnode%d [label=\"End\"];", nodeId));
            graphLines.add(String.format("\tnode%d -> node%d;", nodeId - 1, nodeId));
            graphLines.add("}");

            // Extract the name of the file without the extension
            String baseFileName = selectedFile.getName().replaceFirst("[.][^.]+$", "");

            try (BufferedWriter writer = new BufferedWriter(new FileWriter(baseFileName+ ".dot"))) {
                for (String line : graphLines) {
                    writer.write(line);
                    writer.newLine();
                }
            }

            System.out.println("Dot file generated");
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    private static void addNode(String label) {
        String sanitizedLabel = label
            .replaceAll("\"", "\\\\\"")
            .replaceAll("\n", " ");

        graphLines.add(String.format("\tnode%d [label=\"%s\"];", nodeId, sanitizedLabel));
        if (nodeId > 0) { // Ensure we connect the start node to the main method node directly
            graphLines.add(String.format("\tnode%d -> node%d;", nodeId - 1, nodeId));
        }
        nodeId++;
    }

    private static void addSingleNode(String label) {
        String sanitizedLabel = label.replaceAll("\"", "\\\\\"").replaceAll("\n", " ");
        graphLines.add(String.format("\tnode%d [label=\"%s\"];", nodeId, sanitizedLabel));
        nodeId++;
    }
    

    private static class DeclarationCollector extends VoidVisitorAdapter<Void> {
        @Override
        public void visit(MethodDeclaration n, Void arg) {
            methodMap.put(n.getNameAsString(), n);
            super.visit(n, arg);
        }
    }

    private static class CFGVisitor extends VoidVisitorAdapter<Void> {

    private final LinkedList<Integer> endNodesStack = new LinkedList<>();
        private boolean insideIfOrElseBlock = false;

        @Override
        public void visit(MethodDeclaration n, Void arg) {

            if (isFirstMethod) {
                // Directly connect the start node to this method's entry node
                isFirstMethod = false; // Set to false to indicate the first method has been processed
            }
            
            // Your existing method visiting logic here
            super.visit(n, arg);
            // Method body is now visited directly without adding a separate node for the method declaration
            n.getBody().ifPresent(body -> body.accept(this, null));
        }

        @Override
        public void visit(ExpressionStmt n, Void arg) {
            if (insideIfOrElseBlock) {
                addSingleNode("Statement: " + n.toString());
            } else {
                addNode("Statement: " + n.toString());
            }
        }

        @Override
        public void visit(BlockStmt n, Void arg) {
            for (Statement stmt : n.getStatements()) {
                stmt.accept(this, arg);
            }
        }

        @Override
        public void visit(ForStmt n, Void arg) {
            // Combine the initialization, condition, and update parts of the for loop into a single label
            String forLoopLabel = "For Loop: Init=" + n.getInitialization() + ", Cond=" + n.getCompare().orElse(null) + ", Update=" + n.getUpdate();
            addNode(forLoopLabel);
            int forLoopNodeId = nodeId - 1; // The node ID of the for loop's condition

            // Process the body of the for loop, ensuring all statements inside are added
            n.getBody().accept(this, arg);

            // Optionally, if you want to represent the update part as a separate node (usually it's included in the for loop label)
            // addNode("For Update: " + n.getUpdate());
            // int forUpdateNodeId = nodeId - 1;
            // Connect the last statement of the loop body back to the update part, if represented separately
            // graphLines.add(String.format("\tnode%d -> node%d;", nodeId - 1, forUpdateNodeId));
            // Connect the update part back to the loop's condition to simulate the continuation condition
            // graphLines.add(String.format("\tnode%d -> node%d;", forUpdateNodeId, forLoopNodeId));

            // Connect the last statement inside the for loop back to the for loop condition to represent the loop continuation
            graphLines.add(String.format("\tnode%d -> node%d;", nodeId - 1, forLoopNodeId));

            // Add a node for the end of the for loop to represent the loop's exit point
            addSingleNode("End of For Loop");
            int endForNodeId = nodeId - 1;

            // Connect the for loop node directly to the end of the for loop node to simulate the control flow when the condition is false
            graphLines.add(String.format("\tnode%d -> node%d;", forLoopNodeId, endForNodeId));

        }

        @Override
        public void visit(SwitchStmt n, Void arg) {
            // Add a node for the switch statement's condition
            addNode("Switch: " + n.getSelector().toString());
            int switchNodeId = nodeId - 1;

            // Store the end nodes of each case for later connection to the "end switch" node
            List<Integer> caseEndNodeIds = new ArrayList<>();

            // Process each case in the switch statement
            for (SwitchEntry entry : n.getEntries()) {
                String label = entry.getLabels().isEmpty() ? "Default Case" : "Case: " + entry.getLabels().toString();
                addSingleNode(label);
                int caseNodeId = nodeId - 1; // Node ID of the current case entry
                graphLines.add(String.format("\tnode%d -> node%d;", caseNodeId, nodeId));

                // Connect the switch node to the current case node
                graphLines.add(String.format("\tnode%d -> node%d;", switchNodeId, caseNodeId));

                // Process the statements within the case
                if (!entry.getStatements().isEmpty()) {
                    insideIfOrElseBlock = true; // Disable automatic connection
                    entry.getStatements().forEach(stmt -> stmt.accept(this, arg));
                    insideIfOrElseBlock = false; // Re-enable automatic connection
                    // Store the last statement's node ID of the case for later connection to the "end switch" node
                    caseEndNodeIds.add(nodeId - 1);
                } else {
                    // For cases without statements (i.e., fall-through), connect directly to the next case/end switch
                    caseEndNodeIds.add(caseNodeId);
                }
            }

            // Add a node for the end of the switch statement
            addSingleNode("End of Switch");
            int endSwitchNodeId = nodeId - 1;

            // Connect all case end nodes to the "end switch" node
            caseEndNodeIds.forEach(caseEndNodeId -> graphLines.add(String.format("\tnode%d -> node%d;", caseEndNodeId, endSwitchNodeId)));

        }




        @Override
        public void visit(IfStmt n, Void arg) {
            insideIfOrElseBlock = true;
            int previousNodeId = nodeId - 1; // Keep track of the last node before the if statement
    
            addNode("Condition: " + n.getCondition().toString());
            int conditionNodeId = nodeId - 1; // Subtract one because addNode increments nodeId
    
            // Keep track of the last node ID within 'then' and 'else' branches
            int lastThenNodeId = -1;
            int lastElseNodeId = -1;
    
            // Process 'then' branch
            Statement thenStmt = n.getThenStmt();
            if (!isStatementEmpty(thenStmt)) {
                graphLines.add(String.format("\tnode%d -> node%d [label=\"True\"];", conditionNodeId, nodeId));
                thenStmt.accept(this, arg); // This will add all 'then' statements to the graph
                lastThenNodeId = nodeId - 1; // Update the last node ID for the 'then' branch
            }
    
            // Process 'else' branch
            if (n.getElseStmt().isPresent()) {
                Statement elseStmt = n.getElseStmt().get();
                if (!isStatementEmpty(elseStmt)) {
                    graphLines.add(String.format("\tnode%d -> node%d [label=\"False\"];", conditionNodeId, nodeId));
                    elseStmt.accept(this, arg); // This will add all 'else' statements to the graph
                    lastElseNodeId = nodeId - 1; // Update the last node ID for the 'else' branch
                }
            }
    
            // Now add the 'End-if' node
            addSingleNode("End of If-Else Block");
            int endIfNodeId = nodeId - 1;
    
            // Connect the last node of 'then' branch to the 'end-if' node, if 'then' was not empty
            if (lastThenNodeId != -1) {
                graphLines.add(String.format("\tnode%d -> node%d;", lastThenNodeId, endIfNodeId));
            } else {
                // If 'then' was empty, connect the condition node directly to the 'end-if' node
                //graphLines.add(String.format("\tnode%d -> node%d [label=\"True\"];", conditionNodeId, endIfNodeId));
            }
    
            // Connect the last node of 'else' branch to the 'end-if' node, if 'else' was not empty
            if (lastElseNodeId != -1) {
                graphLines.add(String.format("\tnode%d -> node%d;", lastElseNodeId, endIfNodeId));
            } else if (n.getElseStmt().isPresent()) {
                // If 'else' was empty, still need to connect the condition node to the 'end-if' node
                //graphLines.add(String.format("\tnode%d -> node%d [label=\"False\"];", conditionNodeId, endIfNodeId));
            }
    
            // Connect the 'end-if' node to the next node (which will be the next statement after the if-else)
            // Note that this next node is yet to be added, so we use endIfNodeId + 1 as a placeholder
            //graphLines.add(String.format("\tnode%d -> node%d;", endIfNodeId, endIfNodeId + 1));
            nodeId = endIfNodeId + 1; // Increment nodeId to be used for the next actual statement
            insideIfOrElseBlock = false;
        }
    

        private boolean isStatementEmpty(Statement stmt) {
            // This method checks if a given statement is effectively empty.
            if (stmt instanceof BlockStmt) {
                return ((BlockStmt) stmt).getStatements().isEmpty();
            }
            // Consider additional types of statements here if necessary
            return stmt.toString().trim().isEmpty();
        }

        @Override
        public void visit(WhileStmt n, Void arg) {
            // Add a node for the while loop's condition
            addNode("While: " + n.getCondition().toString());
            int whileConditionNodeId = nodeId - 1; // Remember the node ID of the while condition

            // Process the body of the while loop, ensuring all statements inside are added
            // Temporarily disable automatic connection to simulate linear control flow inside the while loop
            n.getBody().accept(this, arg);

            int lastStatementInsideWhileNodeId = nodeId - 1; // Node ID of the last statement inside the while loop

            // Connect the last statement inside the while loop back to the condition
            graphLines.add(String.format("\tnode%d -> node%d;", lastStatementInsideWhileNodeId, whileConditionNodeId));

            // Add a node for the end of the while loop to represent the loop's exit point
            addSingleNode("End of While Loop");
            int endWhileNodeId = nodeId - 1;

            // Connect the while condition directly to the end-while node to simulate the control flow when the condition is false
            graphLines.add(String.format("\tnode%d -> node%d;", whileConditionNodeId, endWhileNodeId));

            // The next node to be added will be the statement immediately outside the while loop
            // Note: At this point, nodeId has already been incremented by addSingleNode,
            // so the connection to the next statement will be added when the next statement node is created.
        }

        @Override
        public void visit(DoStmt n, Void arg) {
            // Add a node for entering the do-while loop
            addNode("Enter Do-While Loop");
            int enterDoWhileNodeId = nodeId - 1;

            // Process the body of the do-while loop, ensuring all statements inside are added
            n.getBody().accept(this, arg);

            // Add a node for the do-while loop's condition
            addNode("Do-While Condition: " + n.getCondition().toString());
            int doWhileConditionNodeId = nodeId - 1;

            // Connect the condition back to the loop's start to represent the potential for looping
            graphLines.add(String.format("\tnode%d -> node%d;", doWhileConditionNodeId, enterDoWhileNodeId));

            // Add a node for the end of the do-while loop to represent the loop's exit point
            addSingleNode("End of Do-While Loop");
            int endDoWhileNodeId = nodeId - 1;

            // Connect the do-while condition to the end of the do-while node, representing the exit condition
            graphLines.add(String.format("\tnode%d -> node%d;", doWhileConditionNodeId, endDoWhileNodeId));

        }

    }
    
}
EOF

echo "Creating pom.xml..."
cat > ${MAIN}/build/JavaParser/pom.xml <<'EOF'
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/maven-v4_0_0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.example</groupId>
  <artifactId>bugswarm-javaparser</artifactId>
  <packaging>jar</packaging>
  <version>1.0-SNAPSHOT</version>
  <name>bugswarm-javaparser</name>
  <url>http://maven.apache.org</url>
  <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.8.1</version> <!-- Use a version that supports Java 11 -->
                <configuration>
                    <source>11</source> <!-- Set source compatibility to Java 11 -->
                    <target>11</target> <!-- Set target compatibility to Java 11 -->
                </configuration>
            </plugin>
        </plugins>
  </build>
  <dependencies>
    <dependency>
      <groupId>junit</groupId>
      <artifactId>junit</artifactId>
      <version>3.8.1</version>
      <scope>test</scope>
    </dependency>
   <dependency>
        <groupId>com.github.javaparser</groupId>
        <artifactId>javaparser-core</artifactId>
        <version>3.23.1</version> <!-- Use the latest version -->
    </dependency>
  </dependencies>
</project>

EOF

# Step 2: Compile the Java files using Maven
echo "Compiling Java files..."
(cd ${MAIN}/build/JavaParser && mvn clean compile > /dev/null 2>&1) 

counter=0
total_files=$(find ${MAIN}/build/ -type f -name "*.java" ! -path "${MAIN}/build/JavaParser/*" | wc -l)
estimated_seconds=$((total_files * 3))

display_time() {
    local total_seconds=$1
    # Check if total_seconds is unset or set to 0
    if [[ -z "$total_seconds" || "$total_seconds" -eq 0 ]]; then
        return
    fi
    local hours=$((total_seconds / 3600))
    local minutes=$(((total_seconds % 3600) / 60))
    local seconds=$((total_seconds % 60))
    echo "${hours}h ${minutes}m ${seconds}s"
}

# Step 3: Traverse ${MAIN}/build/failed/ to find Java files, copy them, run CFGProcessor, and handle the output
echo "Processing Java files..."
echo "Estimated time to finish: $(display_time $estimated_seconds) based on $total_files files."

find ${MAIN}/build/failed/ -type f -name "*.java" | while read java_file; do
    counter=$((counter+1))
    echo "Processing file $counter of $total_files..."
    remaining_files=$((total_files - counter))
    remaining_seconds=$((remaining_files * 3))
    echo "Estimated time left: $(display_time $remaining_seconds)"

    # Calculate the directory structure for the output file
    relative_path="${java_file#${MAIN}/build/}"
    output_dir="/bugswarm-sandbox/JavaParser/${output_dir_name}/$(dirname "$relative_path")"
    mkdir -p "$output_dir"

    # Copy the Java file to the JavaParser project
    cp "$java_file" ${MAIN}/build/JavaParser/src/main/java/com/example/

    # Run CFGProcessor.java
    (cd ${MAIN}/build/JavaParser && mvn exec:java -Dexec.mainClass="com.example.CFGProcessor" > /dev/null 2>&1)

    # Find the newest .dot file after running and move it if present
    latest_dot_file_after=$(find ${MAIN}/build/JavaParser/ -type f -name "*.dot" -printf "%T+ %p\n" | sort -r | head -n 1 | cut -d' ' -f2-)
    if [[ -f "$latest_dot_file_after" ]]; then
        mv "$latest_dot_file_after" "$output_dir/$(basename "$java_file" .java).dot"
        echo "Moved: $(basename "$java_file" .java).dot"
    else
        echo "No .dot file generated for $(basename "$java_file")"
    fi

    # Delete the copied Java file
    rm ${MAIN}/build/JavaParser/src/main/java/com/example/"$(basename "$java_file")"
done

process_java_files() {
    local source_dir=$1
    find ${MAIN}/build/${source_dir}/ -type f -name "*.java" | while read java_file; do
        counter=$((counter + 1))
        echo "Processing file $counter of $total_files..."
        remaining_files=$((total_files - counter))
        remaining_seconds=$((remaining_files * 3))
        echo "Estimated time left: $(display_time $remaining_seconds)"

        relative_path="${java_file#${MAIN}/build/}"
        output_dir="/bugswarm-sandbox/JavaParser/${output_dir_name}/$(dirname "$relative_path")"
        mkdir -p "$output_dir"

        cp "$java_file" ${MAIN}/build/JavaParser/src/main/java/com/example/

        (cd ${MAIN}/build/JavaParser && mvn exec:java -Dexec.mainClass="com.example.CFGProcessor" > /dev/null 2>&1)

        latest_dot_file=$(find ${MAIN}/build/JavaParser/ -type f -name "*.dot" -printf "%T+ %p\n" | sort -r | head -n 1 | cut -d' ' -f2-)
        if [[ -f "$latest_dot_file" ]]; then
            mv "$latest_dot_file" "$output_dir/$(basename "$java_file" .java).dot"
            echo "Moved: $(basename "$java_file" .java).dot"
        else
            echo "No .dot file generated for $(basename "$java_file")"
        fi

        rm ${MAIN}/build/JavaParser/src/main/java/com/example/"$(basename "$java_file")"
    done
}

# Process both failed and passed directories without resetting the counter or time
process_java_files "failed"
process_java_files "passed"

end_time=$(date +%s) # Capture the end time of the script
elapsed=$((end_time - start_time)) # Calculate the elapsed time

echo -e "\nProcessing complete. $counter files processed."
echo "Total processing time: $(display_time $elapsed)."