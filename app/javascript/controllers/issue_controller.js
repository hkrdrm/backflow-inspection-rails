import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["name", "description", "issue_number", "comic_id", "canvas", "image", "form"]

  greet() {
    // const name         = this.nameTarget.value
    // const issue_number = this.issue_numberTarget.value
    // const comic_id     = this.comic_idTarget.value
    // const description  = this.descriptionTarget.value
    //
    // console.log(`Hello, ${name} ${issue_number} ${comic_id} ${description}!`)
  }

  submit(e) {
    e.preventDefault();

    const form = this.formTarget
    form.submit()
  }

  preview() {
    const file = event.target.files[0];

    if(file){
      const reader = new FileReader();
      reader.onload = (e) => {
        this.canvasTarget.src = reader.result;
        this.canvasTarget.removeAttribute("hidden");
      };

      reader.readAsDataURL(file);
    }
  }
}
