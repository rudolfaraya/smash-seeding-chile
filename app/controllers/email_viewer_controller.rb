class EmailViewerController < ApplicationController
  def index
    @email_dirs = Dir.glob(Rails.root.join('tmp', 'letter_opener', '*')).sort.reverse
    @emails = @email_dirs.map do |dir|
      {
        id: File.basename(dir),
        path: dir,
        rich_html: File.join(dir, 'rich.html'),
        plain_html: File.join(dir, 'plain.html'),
        created_at: File.mtime(dir)
      }
    end
  end

  def show
    email_id = params[:id]
    email_path = Rails.root.join('tmp', 'letter_opener', email_id)
    
    unless File.directory?(email_path)
      redirect_to email_viewer_index_path, alert: 'Email no encontrado'
      return
    end

    file_type = params[:type] == 'plain' ? 'plain.html' : 'rich.html'
    file_path = File.join(email_path, file_type)
    
    if File.exist?(file_path)
      render html: File.read(file_path).html_safe
    else
      redirect_to email_viewer_index_path, alert: 'Archivo de email no encontrado'
    end
  end
end
