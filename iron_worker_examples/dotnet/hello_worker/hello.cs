using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Web.Script.Serialization;

public class HelloWorld
{
    static public void Main(string[] args)
    {
        int ind = Array.IndexOf(args, "-payload");
        if( ind >= 0 && (ind+1) < args.Length ){
            string path = args[ind+1];
            IDictionary<string,string> json = new JavaScriptSerializer().Deserialize <Dictionary<string, string>>(File.ReadAllText(path));
            foreach (string key in json.Keys)
            {
                Console.WriteLine( key + " = " + json[key] );
            }
        }
    }

}
