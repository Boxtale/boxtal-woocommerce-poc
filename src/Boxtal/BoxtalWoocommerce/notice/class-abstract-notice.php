<?php
/**
 * Contains code for the abstract notice class.
 *
 * @package     Boxtal\BoxtalWoocommerce\Notice
 */

namespace Boxtal\BoxtalWoocommerce\Notice;

/**
 * Abstract notice class.
 *
 * Base methods for notices.
 *
 * @class       Abstract_Notice
 * @package     Boxtal\BoxtalWoocommerce\Notice
 * @category    Class
 * @author      API Boxtal
 */
abstract class Abstract_Notice {


	/**
	 * Notice key, used for remove method.
	 *
	 * @var string
	 */
	protected $key;

	/**
	 * Notice type.
	 *
	 * @var string
	 */
	protected $type;

	/**
	 * Notice autodestruct.
	 *
	 * @var boolean
	 */
	protected $autodestruct;

	/**
	 * Construct function.
	 *
	 * @param string $key key for notice.
	 * @void
	 */
	public function __construct( $key ) {
		$this->key = $key;
	}

	/**
	 * Render notice.
	 *
	 * @void
	 */
	public function render() {
		$notice = $this;
		if ( $notice->is_valid() ) {
			include realpath( plugin_dir_path( __DIR__ ) ) . DIRECTORY_SEPARATOR . 'assets' . DIRECTORY_SEPARATOR . 'views' . DIRECTORY_SEPARATOR . 'html-' . $this->type . '-notice.php';
			if ( $notice->autodestruct ) {
				$notice->remove();
			}
		} else {
			$notice->remove();
		}
	}

	/**
	 * Remove notice.
	 *
	 * @void
	 */
	public function remove() {
		Notice_Controller::remove_notice( $this->key );
	}

	/**
	 * Check if notice is still valid.
	 *
	 * @boolean
	 */
	public function is_valid() {
		return true;
	}
}