package classes.test;

/*
 * Check that our monitors obey Mesa semantics -- lock is not released
 * immediately upon invocation of notify(), but rather when the notifying thread
 * has reached the end of the synchronized block.
 */
class MesaTest {

  static Object obj = new Object();

  static class Foo implements Runnable {
    Thread thread;

    Foo() {
      thread = new Thread(this);
      thread.start();
    }

    public void run() {
      synchronized(obj) {
        System.out.println("Running " + thread.getName());
        try {
          obj.wait();
        }
        catch (InterruptedException e) {}
        System.out.println("Finishing " + thread.getName());
      }
    }
  }

  static class Bar implements Runnable {
    Thread thread;

    Bar() {
      thread = new Thread(this);
      thread.start();
    }

    public void run() {
      synchronized(obj) {
        System.out.println("Running " + thread.getName());
        obj.notify();
        System.out.println("Finishing " + thread.getName());
      }
    }
  }

  public static void main(String[] args) {
    new Foo();
    synchronized(obj) {
      Thread.currentThread().yield();
    }
    new Bar();
  }

}
