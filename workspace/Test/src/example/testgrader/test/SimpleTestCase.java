package example.testgrader.test;

import junit.framework.TestCase;

public class SimpleTestCase extends TestCase {
	
	public void testAdd(){
		int x = 0;
		int y = 0;
		
		assertTrue((x+y)>0);
	}

}
