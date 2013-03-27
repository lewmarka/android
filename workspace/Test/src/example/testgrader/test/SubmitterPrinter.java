package example.testgrader.test;

import java.io.PrintStream;

import junit.framework.Test;
import junit.framework.TestResult;
import junit.textui.ResultPrinter;

class StringResultPrinter extends ResultPrinter {

    public StringResultPrinter(PrintStream writer) {
        super(writer);
    }
    public void startTest(Test test) {
        getWriter().println("***** About to run " + test);
        getWriter().flush();
    }

//    synchronized void print(TestResult result, long runTime) {
//        printHeader(runTime);
//        printFooter(result);
//    }
}
