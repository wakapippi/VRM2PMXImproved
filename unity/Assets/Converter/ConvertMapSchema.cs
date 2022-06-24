using System.Collections.Generic;

namespace VRM2PMXImproved
{
    public class ConvertMapSchema
    {
        public List<ConvertMapItem> lists;

        public class ConvertMapItem
        {
            public string originalName;
            public string proxyName;
            public string pmxName;
            public string typeString;
        }
    }
}