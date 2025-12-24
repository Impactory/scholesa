import java.util.Scanner;

public class MainFun {
    public static void main(String[] args){
        Scanner myInput = new Scanner(System.in);
        String myName = "";
        System.out.println("Hello there, wanna introduce yourself to me?");

        myName = myInput.nextLine();
        System.out.println("Nice meeting you, " + myName);
        myInput.close();
    }
}
