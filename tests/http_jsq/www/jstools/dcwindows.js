// dcwindows.js

function DCWINDOW(atitle, awidth, aheight)
{
  this.left = 10;
  this.top = 10;
  this.title = atitle;
  this.width = awidth || 500;
  this.height = aheight || 0;
  this.autocenter = true;
  this.visible = false;

  this.window_div = dc_div({style:'position:absolute; border:4px solid #000040; background-color:#F8F8F8; box-shadow:4px 4px 6px #707070;'}); // width:608px;
  this.header_div = dc_div({style:'width:100%; height:25px; background-color:#000040; color:#FFFFFF; font-weight:bold; padding-bottom:4px; line-height:25px; cursor:move;'});
  this.close_button = dc_input_button('', ' X ', {style: 'float:right; height:25px;', OnClick: [this.OnCloseClick, [], this] });
  this.content_div = dc_div();

  this.onclose = null;

  this.titletextnode = dc_text(this.title);

  dc_add(this.window_div,
    this.header_div,
    [
      this.titletextnode,
      this.close_button
    ],
    this.content_div
  );

  dc_dragging(this.header_div, {content : this.window_div});
}

DCWINDOW.prototype.Show = function(atop, aleft)
{
  this.window_div.style.position = 'absolute';
  this.window_div.style.zIndex = dc_maxz();
  this.window_div.style.width = this.width+'px';
  this.window_div.style.height = (this.height ? this.height+'px' : '');

  if (!this.visible)
  {
    document.body.appendChild(this.window_div);
    this.visible = true;
  }

  if (typeof(atop) == 'number')
  {
    this.window_div.style.top = this.top+'px';
    this.window_div.style.left = this.left+'px';
  }
  else
  {
    dc_center(this.window_div);
  }
}

DCWINDOW.prototype.SetTitle = function(atitle)
{
  this.titletextnode.nodeValue = atitle;
}

DCWINDOW.prototype.Hide = function()
{
  if (this.visible)
  {
    document.body.removeChild(this.window_div);
    this.visible = false;
  }
}

DCWINDOW.prototype.OnCloseClick = function()
{
  if (typeof(this.onclose) == 'function')
  {
    this.onclose(this);
  }

  this.Hide();
}

//-----------------------------------------

function DCEDITWIN(atitle, awidth)
{
  var self = this;

  this.win = new DCWINDOW(atitle, awidth);
  this.win.onclose = function() { self.Hide(); };
  this.datarow = null;
  this.captionwidth = 100;
  this.buttonwidth = 80;

  this.BuildContent = null;  // needs override

  this.fields_div = dc_div();
  this.buttons_div = dc_div({style : 'text-align:center; padding: 8px'});

  this.win.content_div.style.backgroundColor = '#B9EAA1';

  dc_add(this.win.content_div, this.fields_div, this.buttons_div);
}

DCEDITWIN.prototype.AddRow = function(caption, varargs)
{
  var contents = [];
  for (var i=1; i < arguments.length; i++)  // skip the first argument
  {
    contents.push(arguments[i]);
  }

  dc_add
  (
    this.fields_div,
    [
      dc_div('border-bottom:1px solid black; display: table; width: 100%'),
      [
        dc_div({ text: caption, style: 'display:table-cell; padding:5px; text-align:right; vertical-align:top;  background-color:#9AD57D; border-right:1px solid black; width:'+this.captionwidth+'px;' }),
        dc_div({ style: 'display:table-cell; padding:5px; vertical-align: top;' }),
        [
          contents
        ]
      ]
    ]
  );
}

DCEDITWIN.prototype.AddHidden = function(name, value)
{
  var hidden = dc_input_hidden(name, value);
  dc_add( this.fields_div, hidden);
  return hidden;
}

DCEDITWIN.prototype.AddButton = function(caption, clickfunc, param, self)
{
  if (typeof(caption) == 'object')
  {
    dc_add(this.buttons_div, caption);
    return caption;
  }

  var btn = dc_input_button('', caption, 'margin-left: 8px; margin-right: 8px; width: '+this.buttonwidth+'px');

  if (typeof(clickfunc) == 'function')
  {
    dc_attr(btn, {OnClick: [clickfunc, param, self]});
  }
  else if (typeof(clickfunc) == 'object')
  {
    dc_attr(btn, clickfunc);
  }

  dc_add(this.buttons_div, btn);

  return btn;
}

DCEDITWIN.prototype.Show = function(adata)
{
  this.datarow = adata;

  if (typeof(this.BuildContent) == 'function')
  {
    dc_clear(this.fields_div);
    dc_clear(this.buttons_div);

    this.BuildContent(this.datarow);
  }

  this.win.Show();
}

DCEDITWIN.prototype.Hide = function(content)
{
  this.win.Hide();

  var func = this.OnClose || this.OnHide;
  if (func)
  {
    func.apply(this);
  }
}

DCEDITWIN.prototype.Collect = function(aurlencode)
{
  var data = dc_collect(this.fields_div);
  if (aurlencode)
  {
    return dc_urlencode(data);
  }
  else
  {
    return data;
  }
}
