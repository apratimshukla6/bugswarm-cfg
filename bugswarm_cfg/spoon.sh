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
mkdir -p ${MAIN}/build/Spoon/src/main/java/com/example
echo "Creating CFGProcessor.java..."
cat > ${MAIN}/build/Spoon/src/main/java/com/example/CFGProcessor.java <<'EOF'
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
    private String className = null;

    public CFGProcessor() {
        graph.append("digraph CFG {\n");
        graph.append("    start [label=\"Start\"];\n"); // Define the start node
    }

    @Override
    public boolean isToBeProcessed(CtMethod<?> candidate) {
        // Get the simple name of the class containing the candidate method
        String className = candidate.getParent(CtClass.class).getSimpleName();
        
        // Ensure processing for all classes except RunSpoon and CFGProcessor
        return !("RunSpoon".equals(className) || "CFGProcessor".equals(className));
    }

    @Override
    public void process(CtMethod<?> method) {
        if (processedMethods.add(method)) {
            if (className == null) {
                // Capture the class name when processing the first method
                className = method.getDeclaringType().getSimpleName();
            }
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
        if (className != null) {
            String outputFileName = className + "_cfg.dot";
            try (FileWriter writer = new FileWriter(outputFileName)) { // Use the class name for the filename
                writer.write(graph.toString()); // Write the CFG to the file
            } catch (IOException e) {
                e.printStackTrace();
            }
        } else {
            System.err.println("No class name captured, cannot write CFG output.");
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
EOF

echo "Creating RunSpoon.java..."
cat > ${MAIN}/build/Spoon/src/main/java/com/example/RunSpoon.java <<'EOF'
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
EOF

echo "Creating pom.xml..."
cat > ${MAIN}/build/Spoon/pom.xml <<'EOF'
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/maven-v4_0_0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.example</groupId>
  <artifactId>spoon-cfg</artifactId>
  <packaging>jar</packaging>
  <version>1.0-SNAPSHOT</version>
  <name>spoon-cfg</name>
  <url>http://maven.apache.org</url>
  <properties>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
  </properties>
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
     <!-- Spoon dependency -->
    <dependency>
        <groupId>fr.inria.gforge.spoon</groupId>
        <artifactId>spoon-core</artifactId>
        <version>10.1.0</version> <!-- Use the latest version -->
    </dependency>
  </dependencies>
</project>
EOF

# Step 2: Compile the Java files using Maven
echo "Compiling Java files..."
(cd ${MAIN}/build/Spoon && mvn clean compile > /dev/null 2>&1)

counter=0
total_files=$(find ${MAIN}/build/ -type f -name "*.java" ! -path "${MAIN}/build/Spoon/*" | wc -l)
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


# Step 3: Traverse ${MAIN}/build/failed/ to find Java files, copy them, run RunSpoon, and handle the output
echo "Processing Java files..."
echo "Estimated time to finish: $(display_time $estimated_seconds) based on $total_files files."

process_java_files() {
    local source_dir=$1
    find ${MAIN}/build/${source_dir}/ -type f -name "*.java" | while read java_file; do
        counter=$((counter + 1))
        echo "Processing file $counter of $total_files..."
        remaining_files=$((total_files - counter))
        remaining_seconds=$((remaining_files * 3))
        echo "Estimated time left: $(display_time $remaining_seconds)"

        # Calculate the directory structure for the output file
        relative_path="${java_file#${MAIN}/build/}"
        output_dir="/bugswarm-sandbox/Spoon/${output_dir_name}/$(dirname "$relative_path")"
        mkdir -p "$output_dir"

        # Copy the Java file to the Spoon project
        cp "$java_file" ${MAIN}/build/Spoon/src/main/java/com/example/

        # Run RunSpoon.java
        (cd ${MAIN}/build/Spoon && mvn exec:java -Dexec.mainClass="com.example.RunSpoon" > /dev/null 2>&1)

        # Find the newest .dot file after running and move it if present
        latest_dot_file=$(find ${MAIN}/build/Spoon/ -type f -name "*.dot" -printf "%T+ %p\n" | sort -r | head -n 1 | cut -d' ' -f2-)
        if [[ -f "$latest_dot_file" ]]; then
            mv "$latest_dot_file" "$output_dir/$(basename "$java_file" .java).dot"
            echo "Moved: $(basename "$java_file" .java).dot"
        else
            echo "No .dot file generated for $(basename "$java_file")"
        fi

        # Delete the copied Java file
        rm ${MAIN}/build/Spoon/src/main/java/com/example/"$(basename "$java_file")"
    done
}

# Process both failed and passed directories without resetting the counter or time
process_java_files "failed"
process_java_files "passed"

end_time=$(date +%s) # Capture the end time of the script
elapsed=$((end_time - start_time)) # Calculate the elapsed time

echo -e "\nProcessing complete. $counter files processed."
echo "Total processing time: $(display_time $elapsed)."