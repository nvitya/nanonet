// parsefunc.js

function DeFuncWrap(astr)
{
  var s = astr.toString();
  if (s.indexOf('function') == 0)
  {
    return s.substr(14, s.length-17);
  }
  else
  {
    return s;
  }
}

//----------------------------------------------------------------------------------------

function StringParser(astr)
{
  this.s = astr;
}

StringParser.prototype.idchars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_01234567890';
StringParser.prototype.numchars = '0123456789';
StringParser.prototype.hexnumchars = '0123456789abcdefABCDEF';

StringParser.prototype.SkipWhite = function()
{
	this.SkipSpaces();

	while (this.s.substr(0,1) == '#')
	{
		// skip until end of the line
		this.ReadToChars('\n\r');
		this.SkipSpaces();
	}
}

StringParser.prototype.SkipSpaces = function()
{
  var whitespaces = ' \n\r\t';
  var cnt = 0;
  while ((cnt < this.s.length) && (whitespaces.indexOf(this.s.charAt(cnt)) >= 0))
  {
    cnt++;
  }

  if (cnt > 0)
  {
    this.s = this.s.substr(cnt, this.s.length);
  }
}

StringParser.prototype.CheckSymbol = function(sym)
{
  if ((sym.length < 1) || (this.s.substr(0,sym.length) != sym))
  {
    return false;
  }

  this.s = this.s.substr(sym.length, this.s.length);

  return true;
}

StringParser.prototype.CheckSymbolKeep = function(sym)
{
  if ((sym.length < 1) || (this.s.substr(0,sym.length) != sym))
  {
    return false;
  }

  return true;
}

StringParser.prototype.NextChar = function()
{
  var result = this.s.substr(0,1);
  this.s = this.s.substr(1, this.s.length);
  return result;
}

StringParser.prototype.ReadToChars = function(stopchars)
{
  var cnt = 0;
  while ((cnt < this.s.length) && (stopchars.indexOf(this.s.charAt(cnt)) < 0))
  {
    cnt++;
  }

  var result = this.s.substr(0,cnt);

  if (cnt > 0)
  {
    this.s = this.s.substr(cnt, this.s.length);
  }

  return result;
}

StringParser.prototype.ReadToSymbol = function(symbol)
{
  var cnt = this.s.indexOf(symbol);
  if (cnt < 0)
  {
    cnt = s.length-1;
  }

  var result = this.s.substr(0,cnt+1);
  this.s = this.s.substr(cnt, this.s.length);
  return result;
}


StringParser.prototype.GetIdentifier = function()
{
  var cnt = 0;

  while ((cnt < this.s.length) && (this.idchars.indexOf(this.s.charAt(cnt)) >= 0))
  {
    if ((cnt == 0) && (this.numchars.indexOf(this.s.charAt(cnt)) >= 0))
    {
      break;
    }
    cnt++;
  }

  var result = this.s.substr(0,cnt);

  if (cnt > 0)
  {
    this.s = this.s.substr(cnt, this.s.length);
  }

  return result;
}

StringParser.prototype.GetNumber = function()
{
  var cnt = 0;

  while ((cnt < this.s.length) && (this.numchars.indexOf(this.s.charAt(cnt)) >= 0))
  {
    cnt++;
  }

  var result = this.s.substr(0,cnt);
  if (cnt > 0)
  {
    this.s = this.s.substr(cnt, this.s.length);
  }
  return result;
}

StringParser.prototype.GetHexNumber = function()
{
  // allow to start with "0x" or "0X"
  if (!this.CheckSymbol('0x'))
  {
    this.CheckSymbol('0X');
  }

  var cnt = 0;

  while ((cnt < this.s.length) && (this.hexnumchars.indexOf(this.s.charAt(cnt)) >= 0))
  {
    cnt++;
  }

  var result = this.s.substr(0,cnt);
  if (cnt > 0)
  {
    this.s = this.s.substr(cnt, this.s.length);
  }
  return result;
}
