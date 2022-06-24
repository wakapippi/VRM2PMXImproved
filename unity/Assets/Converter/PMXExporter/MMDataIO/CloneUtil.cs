using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace MMDataIO
{
    public class CloneUtil
    {
        public static T Clone<T>(T src) where T : ICloneable {
            return (T)src.Clone();
        }

        public static T[] CloneArray<T>(T[] src) where T : ICloneable
        {
            return Array.ConvertAll(src, t => (T)t.Clone());
        }

        public static int[] CloneArray(int[] src)
        {
            return Array.ConvertAll(src, t => t);
        }

        public static float[] CloneArray(float[] src)
        {
            return Array.ConvertAll(src, t => t);
        }

        public static string[] CloneArray(string[] src)
        {
            return Array.ConvertAll(src, t => t);
        }
    }
}
