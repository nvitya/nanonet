function AjaxRequest(callbackFunc, dataSourceUrl, dataToPost, asyncRequest)
{
  var XMLHttpRequestObject = false;

  if (window.XMLHttpRequest)
  {
    XMLHttpRequestObject = new XMLHttpRequest();
  }
  else if (window.ActiveXObject)
  {
    XMLHttpRequestObject = new ActiveXObject('Microsoft.XMLHTTP');
  }

  if (XMLHttpRequestObject)
  {
    if (asyncRequest === undefined) asyncRequest = true;

    XMLHttpRequestObject.onreadystatechange = function()
    {
      if (XMLHttpRequestObject.readyState == 4)
      {
        if (typeof(callbackFunc) == 'function')
        {
          callbackFunc(XMLHttpRequestObject.responseText, XMLHttpRequestObject.status);
        }

        if (asyncRequest) delete XMLHttpRequestObject;
      }
    }

    dataToPost = (dataToPost === undefined) ? null : String(dataToPost);

    if (dataToPost)
    {
      XMLHttpRequestObject.open('POST', dataSourceUrl, asyncRequest);
      XMLHttpRequestObject.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
    }
    else
    {
      XMLHttpRequestObject.open('GET', dataSourceUrl, asyncRequest);
    }

    XMLHttpRequestObject.send(dataToPost);

    if (!asyncRequest)
    {
      var res = { status:XMLHttpRequestObject.status, data:XMLHttpRequestObject.responseText };
      delete XMLHttpRequestObject;
      return res;
    }
  }
}

function DecompressSqlData(obj)
{
  if ((obj.fieldnames !== undefined) && (typeof(obj.data) == 'object') && (obj.data instanceof Array) && (obj.data.length > 0))
  {
    for (var di in obj.data)
    {
      var d = {};

      for (var fi in obj.fieldnames)
      {
        d[obj.fieldnames[fi]] = obj.data[di][fi];
      }

      obj.data[di] = d;
    }
  }
}

function AsyncJsQuery(callbackFunc, requestUrl, dataToPost)
{
  var dat = (typeof(dataToPost) == 'object' ? JSON.stringify(dataToPost) : dataToPost);

  var AsyncCallback = function(data, status)
  {
    if (typeof(callbackFunc) != 'function') return;

    if (status == 200)
    {
      try
      {
        var obj = eval('('+data+')'); // the JSON object does not accept unquoted identifiers
      }
      catch(e)
      {
        callbackFunc( { error:702, errormsg:'JSON error:' + data } );
        return;
      }

      DecompressSqlData(obj);
      callbackFunc(obj);
    }
    else
    {
      var err = (status == 0 ? 600 : status);
      callbackFunc( { error:err, errormsg:'HTTP error:' + err + ', url:' + requestUrl } );
    }
  }

  AjaxRequest(AsyncCallback, requestUrl, dat, true);
}

function SyncJsQuery(requestUrl, dataToPost)
{
  var dat = (typeof(dataToPost) == 'object' ? JSON.stringify(dataToPost) : dataToPost);
  var res = AjaxRequest(null, requestUrl, dat, false);

  if (res.status == 200)
  {
    try
    {
      var obj = eval('('+res.data+')'); // the JSON object does not accept unquoted identifiers

      DecompressSqlData(obj);
      return obj;
    }
    catch(e)
    {
      return { error:700, errormsg:'JSON error:' + res.data }
    }
  }
  else
  {
    var err = (res.status == 0 ? 600 : res.status);
    return { error:err, errormsg:'HTTP error:' + err + ', url:' +requestUrl };
  }
}


function NumberVal(n, defval)
{
  var n2 = Number(n)
  if (!isNaN(n2)) return n2;
  if (isNaN(defval)) return 0;
  return defval;
}

function StringVal(s, defval)
{
  if ((s !== undefined) && (s != null))
  {
    return String(s);
  }
  if (defval !== undefined) return defval;
  return '';
}

function XmlStr(astr)
{
  var result = new String(astr);

  result = result.replace(/&/g, "&#38;");
  result = result.replace(/</g, "&#60;");
  result = result.replace(/>/g, "&#62;");
  result = result.replace(/'/g, "&#39;");
  result = result.replace(/"/g, "&#34;");

  return result;
}

function XmlStrQ(astr)
{
  return "'" + XmlStr(astr) + "'";
}

function JsStrNq(astr)
{
  var result = new String(astr);

  result = result.replace(/\\/g, "\\x5C");

  result = result.replace(/\x08/g, "\\x08");
  result = result.replace(/\t/g, "\\t");
  result = result.replace(/\n/g, "\\n")
  result = result.replace(/\f/g, "\\f");
  result = result.replace(/\r/g, "\\r");
  result = result.replace(/\v/g, "\\v");

  result = result.replace(/"/g, "\\x22");
  result = result.replace(/&/g, "\\x26");
  result = result.replace(/'/g, "\\x27");
  result = result.replace(/</g, "\\x3C");
  result = result.replace(/>/g, "\\x3E");

  return result;
}

function JsStr(astr)
{
  return "'" + JsStrNq(astr) + "'";
}

function AddLoadEvent() // usage: AddLoadEvent(funcToCall, [param1..paramN]);
{
  var oldonload = window.onload;
  var func = arguments[0];
  var args = new Array();

  for (var i = 1; i < arguments.length; i++)
    args.push(arguments[i]);

  window.onload = function()
  {
    if (typeof(oldonload) == 'function')
      oldonload();

    func.apply(this, args);
  }
}
