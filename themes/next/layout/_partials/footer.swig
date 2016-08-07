<div class="copyright" >
  {% set current = date(Date.now(), "YYYY") %}
  &copy; {% if theme.since and theme.since != current %} {{ theme.since }} - {% endif %}
  <span itemprop="copyrightYear">{{ current }}</span>
  <span class="with-love">
    <i class="fa fa-heart"></i>
  </span>
  <span class="author" itemprop="copyrightHolder"><a href="{{config.root}}">{{ config.title }}</a></span>
</div>

<div>
  友情链接 >> 
  <a href="https://elephantme.github.io/" target='_blank'>Elephant Me</a>
</div>

