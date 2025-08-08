// dctabs.js

/*

FIELD PROPERTIES:

t  || title          : text only title
s  || style          : green or g, blue or b, red or r, yellow or y
a  || align          : left or l, center or c, right or r
w  || width          : cell width
f  || sumfunc || func : sum, min, max, avg, count
-- p  || postfix        : can be html formatted text too
df || datafunc       : callback returning the cell value: datafunc(row, fname)
ff || formatfunc     : callback returning the cell text: formatfunc(cellvalue, fname, row)
i  || info || tt || tooltip : tooltip, can be function, fieldname and special string. 's:tooltip' - simple string 'tooltip', 'f:fieldname'
iw || ttw || iwidth || ttwidth        : tooltip width
htt || headertooltip : header tooltip - direct text only
d  || data           : any data string
-- h  || html           : any html property for the given cell
v || visible         : is the cell visible?

lf || linkfunc       : makes link from the cell, function(row, rownum, fname, tabs)

PROPERTIES:

sortable = true
noheader = false

CALLBACKS:

onrowprepare = function(row, rownum) : if returns false, the row won't be displayed

onrowbegin   = function(row, rownum, tr, tabs)
onrowend     = function(row, rownum, tr, tabs)

oncellbegin  = function(row, rownum, fname, td, tabs)
oncellend    = function(row, rownum, fname, td, tabs)

onrowselect  = function(row, rownum, tabs)

*/

//var DCTABS_DEFAULTS = {};

function DCTABS(afields, aprops)
{
  this.data = [];
  this.fields = afields;

  this.noheader = false;
  this.sortable = true;
  this.sortfield = '';
  this.sortreverse = false;

  this.roworder = [];

  this.sums = {};

  this.prepared = false;

  this.onrowprepare = null;
  this.onrowbegin = null; // for custom field calculations
  this.onrowend = null;   // for custom formatting
  this.oncellbegin = null;
  this.oncellend = null;

  this.selectedrow = null;
  this.onrowselect = null;

  this._table = dc_table({class:'TABS', cellSpacing:1, cellPadding:0, border:0});
  this._tr = null;
  this._td = null;

  if (aprops)
  {
    for (var pn in aprops)
    {
      if (typeof(this[pn]) != 'undefined')
      {
        this[pn] = aprops[pn];
      }
    }
  }
}

DCTABS.prototype.propaliases =
{
  t:'title',
  a:'align',
  w:'width',
  s:'style',
  ff:'formatfunc',
  df:'datafunc',
  d:'data',
  i:'tooltip', info:'tooltip', tt:'tooltip',
  iw: 'tooltipwidth', ttw:'tooltipwidth', iwidth:'tooltipwidth', infowidth:'tooltipwidth',
  htt:'headertooltip',
  ts:'thousands',
  f:'sumfunc', func:'sumfunc',
  lf:'linkfunc',
  img:'image',
  v: 'visible'
};

DCTABS.prototype.Prepare = function()
{
  this.sortfield = '';
  this.sortreverse = false;

  // handle property aliases
  for (var fname in this.fields)
  {
    var f = this.fields[fname];
    for (var pn in f)
    {
      var fullname = this.propaliases[pn];
      if (fullname !== undefined)
      {
        f[fullname] = f[pn];
      }
    }
  }

  // prepare order and sums

  this.roworder = [];
  this.sums = {};

  var i;
  for (i = 0; i < this.data.length; i++)
  {
    var row = this.data[i];

    var removerow = false;
    if (this.onrowprepare)
    {
      var res = this.onrowprepare(row, i);
      removerow = (res === false);
    }

    if (!removerow)
    {
      this.roworder.push(i);
      for (var fname in this.fields)
      {
        var field = this.fields[fname];
        var value = this.CellValue(fname, row, field);
        this.SumField(fname, value);
      }
    }
  }
}

DCTABS.prototype.SumField = function(fname, value)
{
  var sf = this.sums[fname];
  if (sf === undefined)
  {
    sf = {sum: 0, cnt:0, minval: null, maxval: null};
    this.sums[fname] = sf;
  }

  if (typeof(value) == 'number')
  {
    sf.cnt++;
    sf.sum += value;
    sf.minval = (sf.minval === null || sf.minval > value ? value : sf.minval);
    sf.maxval = (sf.maxval === null || sf.maxval < value ? value : sf.maxval);
  }
}

DCTABS.prototype.ThousandsSeparator = function(num)
{
  var ts = ' ';
  var ds = '.';
  var ns = String(num);
  var ps = ns;
  var ss = '';
  var i = ns.indexOf('.');

  if (i != -1)
  {
    ps = ns.substring(0, i);
    ss = ds+ns.substring(i + 1);
  }

  return ps.replace(/(\d)(?=(\d{3})+([.]|$))/g, '$1' + ts) + ss;
}

DCTABS.prototype.AddHeader = function()
{
  var tr = dc_tr();
  dc_add(this._table, tr);

  for (var fname in this.fields)
  {
    var field = this.fields[fname];
    if (field.visible !== false)
    {
      var th = dc_th_text(this.fields[fname].title);
      if (this.sortable && (field.sortable !== false))
      {
        dc_attr(th, {OnClick: [this.SortColumn, fname, this]});

        if (this.sortfield == fname)
        {
          th.className = 's';
          var orchr = (this.sortreverse ? String.fromCharCode(0x25BC) : String.fromCharCode(0x25B2));
          dc_add(th, dc_hspace(4), dc_text(orchr));
        }
      }

      if (typeof(field.headertooltip) == 'string')
      {
        dc_tooltip(th, field.headertooltip);
      }

      dc_add(tr, th);
    }
  }
}

DCTABS.prototype.SortColumn = function(fname)
{
  if (this.sortfield == fname)
  {
    this.sortreverse = !this.sortreverse;
  }
  else
  {
    this.sortfield = fname;
    this.sortreverse = false;
  }

  var tab = this;

  this.roworder.sort(
    function(i1, i2)
    {
      var v1 = tab.CellValue(fname, tab.data[i1], tab.fields[fname]);
      var v2 = tab.CellValue(fname, tab.data[i2], tab.fields[fname]);

      if (tab.sortreverse)
      {
        if (v1 < v2)  return +1;
        if (v1 > v2)  return -1;
        if (i1 < v2)  return +1;
        if (i1 > v2)  return -1;
        return 0;
      }
      else
      {
        if (v1 > v2)  return +1;
        if (v1 < v2)  return -1;
        if (i1 > v2)  return +1;
        if (i1 < v2)  return -1;
        return 0;
      }
    }
  );

  this.Update();
}

DCTABS.prototype.AddFooter = function()
{
  var tr = dc_tr();
  var td;

  var hasfooter = false;

  var emptycells = 0;

  for (var fname in this.fields)
  {
    var f = this.fields[fname];
    var hasdata = true;
    var fsum = this.sums[fname];

    var v = null;

    /**/ if (f.sumfunc == 'sum')   v = fsum.sum;
    //else if (f.sumfunc == 'sum1')  s += FormatFooterCell(tab, Math.round(f.___calcs.sum1val), fname);
    //else if (f.sumfunc == 'sum2')  s += FormatFooterCell(tab, Math.round(f.___calcs.sumval), fname);
    else if (f.sumfunc == 'min')   v = fsum.minval;
    else if (f.sumfunc == 'max')   v = fsum.maxval;
    else if (f.sumfunc == 'avg')   v = (fsum.cnt > 0 ? fsum.sum / fsum.cnt : null);
    else if (f.sumfunc == 'count') v = this.sums[fname].cnt;
    else
    {
      hasdata = false;
    }

    if (hasdata && v === null)  hasdata = false;

    if (hasdata)
    {
      if (emptycells > 0)  dc_add(tr, td);
      emptycells = 0;
      hasfooter = true;
      dc_add(tr, dc_td_text(this.FormatCellValue(v, this.data[0], fname, f), {class: 'ar sum'}));
    }
    else
    {
      emptycells++;
      if (emptycells <= 1)
      {
        td = dc_td({class: 'sum'});
      }
      else
      {
        td.colSpan = emptycells;
      }
    }
  }

  if (emptycells > 0)  dc_add(tr, td);

  if (hasfooter)
  {
    dc_add(this._table, tr);
  }
}

DCTABS.prototype.AddRow = function(rownum, row)
{
  this._tr = dc_tr();

  if (row == this.selectedrow)
  {
    this._tr.className = 'hl';
  }

  if (this.onrowbegin)
  {
    this.onrowbegin(row, rownum, this._tr, this);
  }

  for (var fname in this.fields)
  {
    this.AddCell(rownum, row, fname, this.fields[fname]);
  }

  dc_add(this._table, this._tr);

  if (this.onrowend)
  {
    this.onrowend(row, rownum, this._tr, this);
  }
}

DCTABS.prototype.SetCellClass = function(td, celldata, field)
{
  var a = field.align || '';
  var s = field.style || '';
  var c = '';

  if (a == 'l' || a == 'left')   c += 'al ';
  if (a == 'c' || a == 'center') c += 'ac ';
  if (a == 'r' || a == 'right')  c += 'ar ';

  if (a == '' && typeof(celldata) == 'number')  c = 'ar';

  if (s == 'r' || s == 'red')    c += 'sr ';
  if (s == 'g' || s == 'green')  c += 'sg ';
  if (s == 'b' || s == 'blue')   c += 'sb ';
  if (s == 'y' || s == 'yellow') c += 'sy ';

  //if (typeof(extra) == 'string' && extra.length > 0) c += ' ' + extra;

  if (typeof(field.css) == 'string')
  {
    td.style.cssText = field.css;
  }

  td.className = c;
}

DCTABS.prototype.CellValue = function(fname, row, field)
{
  var value; // the content string

  if (typeof(field.datafunc) == 'function')
  {
    value = field.datafunc(row, fname);
  }
  else if (typeof(field.data) == 'string')
  {
    value = field.data;
  }
  else if (typeof(field.image) == 'string')
  {
    value = field.image;
  }
  else
  {
    value = row[fname];
	 if (value === null)
	 {
		value = '';
	 }
  }

  return value;
}

DCTABS.prototype.FormatCellValue = function(cellvalue, row, fname, field)
{
  var cstr; // the content string

  if (typeof(field.formatfunc) == 'function')
  {
    cstr = field.formatfunc(cellvalue, fname, row);
  }
  else if (field.thousands && typeof(cellvalue) == 'number')
  {
    cstr = this.ThousandsSeparator(cellvalue);
  }
  else
  {
    cstr = cellvalue;
  }

  return cstr;
}

DCTABS.prototype.HandleLinkClick = function(e)
{
  var a = e.target;
  a._clickfunc.apply(null, a._clickparams);
}

DCTABS.prototype.AddCell = function(rownum, row, fname, field)
{
  if (field.visible === false)
  {
    return;
  }

  this._td = document.createElement('td');

  if (this.oncellbegin)
  {
    this.oncellbegin(row, rownum, fname, this._td, this);
  }

  var celldata = this.CellValue(fname, row, field);

  this.SetCellClass(this._td, celldata, field);

  var cstr = this.FormatCellValue(celldata, row, fname, field);

  if (field.width || 0 > 0)
  {
    this._td.width = field.width;
  }

  var content;

  if (typeof(field.image) == 'string')
  {
    content = dc_new('img', {src: field.image});
  }
  else if (typeof(field.image) == 'object')
  {
    content = dc_new('img', field.image);
  }
  else
  {
    content = dc_text(cstr);
  }

  if (field.linkfunc)
  {
    var a = dc_a({OnClick: {func: field.linkfunc, args:[row, rownum, fname, this]}});
    a.appendChild(content);
    content = a;
  }
  else
  {
    if (this.onrowselect)
    {
      dc_addevent(this._td, 'click', this.OnRowSelectClick, [row, rownum], this);
      this._td.style.cursor = 'pointer';
    }
  }

  this._td.appendChild( content );

  if (typeof(field.tooltip) == 'string')
  {
    var ttdata = '';
    var tarr = field.tooltip.split(':');
    if (tarr.length > 1)
    {
      if (tarr[0] == 's')  ttdata = tarr[1];
      else ttdata = row[tarr[1]];
    }
    else
    {
      ttdata = row[field.tooltip];
    }

    if (ttdata != '')
    {
      dc_tooltip(this._td, ttdata, {width: field.tooltipwidth || 300});
    }
  }

  if (this.oncellend)
  {
    this.oncellend(row, rownum, fname, this._td, this);
  }

  this._tr.appendChild( this._td );
}

DCTABS.prototype.OnRowSelectClick = function(row, rownum)
{
  this.selectedrow = row;
  this.Update();

  if (this.onrowselect)
  {
    this.onrowselect(row, rownum, this);
  }
}

DCTABS.prototype.AddBody = function()
{
  var i;
  for (var i in this.roworder)
  {
    var rownum = this.roworder[i];
    this.AddRow(i, this.data[rownum]);
  }
}

DCTABS.prototype.Update = function()
{
  dc_clear(this._table);

  if (!this.noheader) this.AddHeader();
  this.AddBody();
  this.AddFooter();

  this.prepared = true;
  this._tr = null;
  this._td = null;
}

DCTABS.prototype.Render = function(adata)
{
  this.data = adata;
  this.prepared = false;
  this.Prepare();
  this.Update();
  return this._table;
}

DCTABS.prototype.RenderTo = function(adata, atarget)
{
  var target = dc_get(atarget);

  if (typeof(target) == 'object')
  {
    dc_clear(target);
    dc_add(target, this.Render(adata));
  }
}
