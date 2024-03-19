#!/bin/bash
start_time=$(date +%s) # Capture start time of the script
run_passed.sh

MAIN="/home/github"

# The first command line argument is used as the directory name
output_dir_name=$1
if [ -z "$output_dir_name" ]; then
    echo "Error: No directory name provided as an argument."
    exit 1
fi

# Step 1: Create the required directory structure and files
mkdir -p ${MAIN}/build/Soot/output/dotfiles
mkdir -p ${MAIN}/build/Soot/src/main/java/com/aiman/cfggenerator
echo "Creating CFGProcessor.java..."
cat > ${MAIN}/build/Soot/src/main/java/com/aiman/cfggenerator/CFGProcessor.java <<'EOF'
package com.aiman.cfggenerator;

import soot.*;
import soot.jimple.JimpleBody;
import soot.options.Options;
import soot.toolkits.graph.ClassicCompleteUnitGraph;
import soot.toolkits.graph.UnitGraph;
import soot.util.dot.DotGraph;

public class CFGProcessor {

    public static String sourceDirectory = "src/main/java/com/aiman/examples";
    public static String clsName = "App";
    public static String methodName = "main";

    public static void setupSoot(String className) {
        G.reset();
        Options.v().set_prepend_classpath(true);
        Options.v().set_allow_phantom_refs(true);
        Options.v().set_soot_classpath(sourceDirectory);
        SootClass sc = Scene.v().loadClassAndSupport(className);
        sc.setApplicationClass();
        Scene.v().loadNecessaryClasses();
    }


    public static void main(String[] args) {
        try {
            System.out.println("Hello"+args[0]);
            setupSoot(args[0]);

            // Retrieve example class body
            System.out.println("Class File name = " + args[0]);
            SootClass mainClass = Scene.v().getSootClass(args[0]);
            // SootMethod sm = mainClass.getMethodByName(methodName);
            System.out.println("Size = " + mainClass.getMethods().size());
            if (mainClass.getMethods().size() > 1) {
                  SootMethod sm = mainClass.getMethods().get(1);
                  System.out.println("Retreived first method");
                  JimpleBody body = (JimpleBody) sm.retrieveActiveBody();
                  UnitGraph ug = new ClassicCompleteUnitGraph(sm.getActiveBody());
                  generateDotGraphFromUnitGraph(sm, ug, "output/dotfiles/" + sm.getName() + ".dot");
            } else {
              System.out.println("no methods found");
            }
        } catch(Exception e) {
            e.printStackTrace();
        }
    }

    public static void generateDotGraphFromUnitGraph(SootMethod method, UnitGraph graph, String outputFileName) {
        DotGraph dot = new DotGraph(outputFileName);
        dot.setGraphLabel(method.getName());

        // Create a node for each unit in the graph
        for (Unit unit : graph) {
            String unitId = unit.toString();
//            dot.drawNode(unitId).setLabel(unitId.substring(0, Math.min(unitId.length(), 50))); // Truncate long labels
            dot.drawNode(unitId).setLabel(unitId);
        }

        // Create an edge for each successor relationship
        for (Unit unit : graph) {
            String srcId = unit.toString();
            for (Unit succ : graph.getSuccsOf(unit)) {
                String dstId = succ.toString();
                dot.drawEdge(srcId, dstId);
            }
        }

        // Save the DotGraph to a file
        dot.plot(outputFileName);
    }
}
EOF

mkdir -p ${MAIN}/build/Soot/src/main/java/com/aiman/dot/graph
echo "Creating DotNode.java..."
cat > ${MAIN}/build/Soot/src/main/java/com/aiman/dot/graph/DotNode.java <<'EOF'
package com.aiman.dot.graph;

import java.util.ArrayList;
import java.util.List;

public class DotNode {

    /* labels are sequence of string statements to print at final generation */
    private String name, label, shape, color, identifier;
    private List<String> labels;
    private boolean ifNode;

    /* shapes: box, ellipse, oval, circle, point, triangle, hexagon, custon
               double....*/
    public DotNode (String arg1, String arg2, String arg3, String arg4) {
        identifier = " ";
        name  = arg1;
        label = arg2;
        shape = arg3;
        color = arg4;
        labels = new ArrayList<String>();
        ifNode = false;
    }

    public DotNode (String arg1) {
        this(arg1, " ", "box", "black");
    }

    public DotNode () {
        this(" ", " ", "box", "black");
    }

    public void setName (String arg1) {
        name = arg1;
    }

    public void setLabel (String arg1) {
        label = arg1;
    }

    public void setColor (String arg1) {
        color = arg1;
    }

    public void setShape (String arg1) {
        shape = arg1;
    }

    public void setIfNode() {
        ifNode = true;
    }

    public boolean isIfNode() {
        return ifNode;
    }

    public void setId (String id) {
        identifier = id;
    }

    public String getId () {
        return identifier;
    }

    public String getName () {
        return name;
    }

    public String getColor () {
        return color;
    }

    public String getShape () {
        return shape;
    }

    public String getLabel () {
        return label;
    }

    public void addLine (String line) {
        labels.add(line);
    }

    public void addLines (List<String> lines) {
        for (String line : lines) {
            labels.add(line);
        }
    }

    public Boolean hasLine (String line) {
        return labels.contains(line);
    }

    public Boolean removeLine (String line) {
        return labels.remove(line);
    }

    public String toString () {
        String body;

        shape = "record";
        body = "\t\"" + identifier + "\" [shape=" + shape + ", color=" + color + ", label=\"{<head>";
        body += name + ":";
        for (String line: labels) {
            body += "\\l";
            line = line.replace("\"","\\\"");
            line = line.replace("<","\\<");
            line = line.replace(">","\\>");
            line = line.replace("###",">");
            line = line.replace("##","<");
            body += "   " + line;
        }
        body += "}\"];";
        return body;
    }

}
EOF

echo "Creating DotGraph.java..."
cat > ${MAIN}/build/Soot/src/main/java/com/aiman/dot/graph/DotGraph.java <<'EOF'
package com.aiman.dot.graph;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class DotGraph {

    private String packageName, definingClassName, methodName, outfile;
    private List<String> methodArguments;
    private List<DotNode> nodes;
    private Map<String, List<String>> edges;
    private List<String> ifNodes;
    private Integer autoId;

    public DotGraph (String pkg, String dc, String method, String file) {
        packageName = pkg;
        definingClassName = dc;
        outfile = file.replace('$','-').replace('<','.').replace('>','T');
        methodName = method;
        autoId = 0;
        nodes = new ArrayList<DotNode>();
        edges = new HashMap<String, List<String>>();
        ifNodes = new ArrayList<String>();
        methodArguments = new ArrayList<String>();
    }

    public DotGraph () {
        this("Package", "Class", "methodName", "default-output-file.dot");
    }

    public void setPackageName (String name) {
        packageName = name;
    }

    public void setDefiningClass (String name) {
        definingClassName = name;
    }

    public void setOutput (String name) {
        outfile = name;
    }

    public void setMethod (String name) {
        methodName = name;
    }

    // todo: define get methods

    public void newNode (List<String> lines, String name, String label, String shape,
                         String color, List<String> succs, boolean ifNode) {

        DotNode dotNode = new DotNode(name, label, shape, color);

        if (ifNode)
            ifNodes.add(name);

        dotNode.setId(name);
        autoId++;

        dotNode.addLines(lines);
        nodes.add(dotNode);


        if (! edges.containsKey(name)) {
            List<String> adjList = new ArrayList<String>();
            edges.put(name, adjList);
        }

        List<String> adjList = edges.get(name);
        for (String succ : succs) {
            adjList.add(succ);
        }
    }

    public void genDotFile() {
        System.out.println("Generating dot file");

        PrintWriter pw = null;
        try {
            File file = new File(outfile);
            FileWriter fw = new FileWriter(file, true);
            pw = new PrintWriter(fw);
            String add = "";

            pw.println("digraph \"CFG for '"+ methodName + "' method\" {");
            pw.println("\tlabel=\"CFG for '" + "." + methodName + "' method of class '"
                    + definingClassName + "'\"; ");

            /* printing all edges */
            for (Map.Entry<String, List<String>> entry : edges.entrySet()) {
                String from = entry.getKey();
                if (ifNodes.contains(from)) {
                    String id = ":s1";
                    for (String to : entry.getValue()) {
                        pw.println("\t" + from + id + " -> \"" + to + "\";");
                        id = ":s0";
                    }
                } else
                    for (String to : entry.getValue()) {
                        if (ifNodes.contains(to))
                            add = ":head";
                        pw.println("\t" + from + " -> " + to + add + ";");
                        add = "";
                    }
            }

            /* printing nodes' body */
            for (DotNode dotNode : nodes) {
                pw.println(dotNode.toString() + "\n");
            }

            pw.println("}");
        } catch (IOException e) {
            e.printStackTrace();
        } finally {
            if (pw != null) {
                pw.close();
            }
        }
    }

}
EOF


echo "Creating pom.xml..."
cat > ${MAIN}/build/Soot/pom.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.aiman</groupId>
    <artifactId>cfg-generator</artifactId>
    <version>1.0-SNAPSHOT</version>
    <name>CFG Generator</name>

    <properties>
        <maven.compiler.source>1.8</maven.compiler.source>
        <maven.compiler.target>1.8</maven.compiler.target>
    </properties>
    <repositories>
        <repository>
            <id>jitpack.io</id>
            <url>https://jitpack.io</url>
        </repository>
        <repository>
            <id>/maven.google.com</id>
            <url>https://maven.google.com</url>
        </repository>
    </repositories>

    <dependencies>
        <!-- Soot dependency -->
            <dependency>
                <groupId>org.soot-oss</groupId>
                <artifactId>soot</artifactId>
                <version>4.3.0</version>
            </dependency>
        <dependency>
            <groupId>org.soot-oss</groupId>
            <artifactId>sootup.core</artifactId>
            <version>1.2.0</version>
        </dependency>
        <dependency>
            <groupId>org.soot-oss</groupId>
            <artifactId>sootup.java.core</artifactId>
            <version>1.2.0</version>
        </dependency>
        <dependency>
            <groupId>org.soot-oss</groupId>
            <artifactId>sootup.java.sourcecode</artifactId>
            <version>1.2.0</version>
        </dependency>
        <dependency>
            <groupId>org.soot-oss</groupId>
            <artifactId>sootup.java.bytecode</artifactId>
            <version>1.2.0</version>
        </dependency>
        <dependency>
            <groupId>org.soot-oss</groupId>
            <artifactId>sootup.jimple.parser</artifactId>
            <version>1.2.0</version>
        </dependency>
        <dependency>
            <groupId>org.soot-oss</groupId>
            <artifactId>sootup.callgraph</artifactId>
            <version>1.2.0</version>
        </dependency>
        <dependency>
            <groupId>org.soot-oss</groupId>
            <artifactId>sootup.analysis</artifactId>
            <version>1.2.0</version>
        </dependency>
        <dependency>
            <groupId>com.google.guava</groupId>
            <artifactId>guava</artifactId>
            <version>30.1-jre</version> <!-- Use the latest version -->
        </dependency>
        <dependency>
            <groupId>org.slf4j</groupId>
            <artifactId>slf4j-simple</artifactId>
            <version>1.7.30</version> <!-- Use the latest version -->
        </dependency>
        <!-- Add other dependencies here -->
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <!-- Plugin to compile with Java 8 -->
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.8.1</version>
                <configuration>
                    <source>${maven.compiler.source}</source>
                    <target>${maven.compiler.target}</target>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
EOF

mkdir -p ${MAIN}/build/Soot/src/main/java/com/aiman/examples

# Step 2: Compile the Java files using Maven
echo "Compiling Java files..."
(cd ${MAIN}/build/Soot && mvn clean compile > /dev/null 2>&1)

counter=0
total_files=$(find ${MAIN}/build/ -type f -name "*.class" ! -path "${MAIN}/build/Soot/*" | wc -l)
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


# Step 3: Traverse ${MAIN}/build/failed/ to find Java files, copy them, run Soot, and handle the output
echo "Processing Java files..."
echo "Estimated time to finish: $(display_time $estimated_seconds) based on $total_files files."

#find ${MAIN}/build/failed/ -type f -name "*.class" | while read java_file; do
#    counter=$((counter+1))
#    echo "Processing file $counter of $total_files..."
#    remaining_files=$((total_files - counter))
#    remaining_seconds=$((remaining_files * 3))
#    echo "Estimated time left: $(display_time $remaining_seconds)"
#
#    # Calculate the directory structure for the output file
#    relative_path="${java_file#${MAIN}/build/}"
#    output_dir="/bugswarm-sandbox/Soot/${output_dir_name}/$(dirname "$relative_path")"
#    mkdir -p "$output_dir"
#
#    # Copy the Java file to the Soot project
#    cp "$java_file" ${MAIN}/build/Soot/src/main/java/com/aiman/examples
#    echo "$java_file copied"
#
#    class_name=$(basename "$java_file" .class)
#
#    echo "Class Name Derived = $class_name"
#
#    # Run CFGProcessor.java
#    (cd ${MAIN}/build/Soot && mvn exec:java -Dexec.mainClass="com.aiman.cfggenerator.CFGProcessor" -Dexec.args="$class_name" > /dev/null 2>&1)
#
#    echo "completed executing CFGProcessor"
#
#    # Find the newest .dot file after running and move it if present
#    latest_dot_file_after=$(find ${MAIN}/build/Soot/ -type f -name "*.dot" -printf "%T+ %p\n" | sort -r | head -n 1 | cut -d' ' -f2-)
#    if [[ -f "$latest_dot_file_after" ]]; then
#        mv "$latest_dot_file_after" "$output_dir/$(basename "$java_file" .class).dot"
#        echo "Moved: $(basename "$java_file" .class).dot"
#    else
#        echo "No .dot file generated for $(basename "$java_file")"
#    fi
#
#    # Delete the copied Java file
#    rm ${MAIN}/build/Soot/src/main/java/com/aiman/examples/"$(basename "$java_file")"
#
#    if [ $counter -eq 2 ]; then
#        break
#    fi
#
#done

# Step 4: Traverse ${MAIN}/build/passed/ to find Java files, copy them, run Soot, and handle the output
find ${MAIN}/build/passed/ -type f -name "*.class" | while read java_file; do
    counter=$((counter+1))
    echo "Processing file $counter of $total_files..."
    remaining_files=$((total_files - counter))
    remaining_seconds=$((remaining_files * 3))
    echo "Estimated time left: $(display_time $remaining_seconds)"

    # Calculate the directory structure for the output file
    relative_path="${java_file#${MAIN}/build/}"
    output_dir="/bugswarm-sandbox/Soot/${output_dir_name}/$(dirname "$relative_path")"
    mkdir -p "$output_dir"

    # Copy the Java file to the Soot project
    cp "$java_file" ${MAIN}/build/Soot/src/main/java/com/aiman/examples

    echo "$java_file copied"
    class_name=$(basename "$java_file" .class)
    echo "Class Name Derived = $class_name"

    # Run CFGProcessor.java
    (cd ${MAIN}/build/Soot && mvn exec:java -Dexec.mainClass="com.aiman.cfggenerator.CFGProcessor" -Dexec.args="$java_file"> /dev/null 2>&1)

    echo "completed executing CFGProcessor"

    # Find the newest .dot file after running and move it if present
    latest_dot_file_after=$(find ${MAIN}/build/Soot/ -type f -name "*.dot" -printf "%T+ %p\n" | sort -r | head -n 1 | cut -d' ' -f2-)
    if [[ -f "$latest_dot_file_after" ]]; then
        mv "$latest_dot_file_after" "$output_dir/$(basename "$java_file" .class).dot"
        echo "Moved: $(basename "$java_file" .class).dot"
    else
        echo "No .dot file generated for $(basename "$java_file")"
    fi

    # Delete the copied Java file
    rm ${MAIN}/build/Soot/src/main/java/com/aiman/examples/"$(basename "$java_file")"

    if [ $counter -eq 10 ]; then
        break
    fi
done


end_time=$(date +%s) # Capture the end time of the script
elapsed=$((end_time - start_time)) # Calculate the elapsed time

echo -e "\nProcessing complete. $counter files processed."
echo "Total processing time: $(display_time $elapsed)."