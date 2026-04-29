import { ComponentFixture, TestBed } from '@angular/core/testing';

import { SaRoles } from './sa-roles';

describe('SaRoles', () => {
  let component: SaRoles;
  let fixture: ComponentFixture<SaRoles>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [SaRoles]
    })
    .compileComponents();

    fixture = TestBed.createComponent(SaRoles);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
