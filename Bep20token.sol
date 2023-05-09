<form method="post">
  <label for="country">Ülke Seçin:</label>
  <select id="country" name="country">
    <option value="usa">Amerika</option>
    <option value="uk">İngiltere</option>
    <option value="germany">Almanya</option>
    <option value="france">Fransa</option>
    <option value="belgium">Belçika</option>
    <option value="netherlands">Hollanda</option>
    <option value="sweden">İsveç</option>
<option value="usa"><img src="flags/usa.png" alt="Amerika">Amerika</option>
</select>
  <button type="submit">Göster</button>
</form>

<?php
if ($_POST) {
  $country = $_POST['country'];

  $args = array(
    'meta_key' => 'rating_' . $country,
    'orderby' => 'meta_value_num',
    'order' => 'DESC'
  );
  $tv_ratings = new WP_Query($args);

  if ($tv_ratings->have_posts()) {
    while ($tv_ratings->have_posts()) {
      $tv_ratings->the_post();
      $rating = get_post_meta(get_the_ID(), 'rating_' . $country, true);
      echo '<div>' . get_the_title() . ' - ' . $rating . '</div>';
    }
  } else {
    echo 'TV reyting verileri bulunamadı.';
  }

  wp_reset_postdata(); // WP_Query ile değiştirilen değişkenleri sıfırlayın
}
?>
<?php
// Fonksiyonları dosyaya ekleyin
require_once('functions.php');

// Post ID'leri ve reytingleri depolamak için bir dizi oluşturun
$ratings = array();

// Tüm ülkeler için döngü oluşturun
$countries = array('usa', 'uk', 'germany', 'france', 'belgium', 'netherlands', 'sweden');
foreach ($countries as $country) {

  // Bu ülke için TV reyting verilerini alın
  $args = array(
    'meta_key' => 'rating_' . $country,
    'orderby' => 'meta_value_num',
    'order' => 'DESC',
    'posts_per_page' => -1
  );
  $tv_ratings = new WP_Query($args);

  // Bu ülke için en yüksek reytingi ve ilgili post ID'sini bulun
  if ($tv_ratings->have_posts()) {
    $tv_ratings->the_post();
    $max_rating = get_post_meta(get_the_ID(), 'rating_' . $country, true);
    $max_rating_post_id = get_the_ID();
  } else {
    $max_rating = 0;
    $max_rating_post_id = null;
  }

  // Her post için oy sayısını depolayın
  $ratings[$country] = array();
  if ($tv_ratings->have_posts()) {
    while ($tv_ratings->have_posts()) {
      $tv_ratings->the_post();
      $rating = get_post_meta(get_the_ID(), 'rating_' . $country, true);
      $ratings[$country][get_the_ID()] = array(
        'rating' => $rating,
        'votes' => 0
      );
    }
  }

  // WP_Query ile değiştirilen değişkenleri sıfırlayın
  wp_reset_postdata();

  // En yüksek reytinge sahip post için oy sayısını güncelleyin
  if ($max_rating_post_id) {
    $ratings[$country][$max_rating_post_id]['votes']++;
  }
}

// Tüm oyları toplayın ve birinci olan postu bulun
$votes = array();
foreach ($ratings as $country => $country_ratings) {
  foreach ($country_ratings as $post_id => $post_ratings) {
    $votes[$post_id] += $post_ratings['votes'];
  }
}
arsort($votes);
$winner_post_id = key($votes);

// Şampiyon ülkeyi bulun ve ilgili bayrağı gösterin
$winner_country = null;
foreach ($ratings as $country => $country_ratings) {
  foreach ($country_ratings as $post_id => $post_ratings) {
    if ($post_id == $winner_post_id) {
      $winner_country = $country;
      break;
    }
  }
  if ($winner_country) {
    break;
  }
}

// Tüm TV reyting postlarını gösterin
foreach ($countries as $country) {
  if (!isset($ratings[$country])) {
    continue;
  }
  echo '<h2>' . get_country_name($country) . '</h2>';
  echo '<ol>';
  foreach ($ratings[$country] as $post_id => $post_ratings) {
    echo '<li>' . get_the_title($post_id) . ' - ' . $post_ratings['rating'] . '</li
